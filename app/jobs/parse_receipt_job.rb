class ParseReceiptJob < ApplicationJob
  queue_as :default

  TRANSIENT_ERRORS = [
    OpenAI::Errors::APITimeoutError,
    OpenAI::Errors::APIConnectionError,
    OpenAI::Errors::RateLimitError
  ].freeze

  # Only transient network/availability failures are worth a retry; each attempt
  # is a full paid vision call, so deterministic failures (bad JSON, invalid
  # records, unsupported images) fail fast via the rescue in #perform instead.
  retry_on(*TRANSIENT_ERRORS, wait: :polynomially_longer, attempts: 3) do |job, error|
    mark_failed(job.arguments.first, error)
  end

  # The check was deleted while the job was queued — nothing to parse.
  discard_on ActiveJob::DeserializationError

  def self.mark_failed(check, error)
    return unless check

    # Set the recovery status first so a failure in reporting or broadcasting
    # can't leave the check stranded in "parsing".
    check.update!(status: "failed")
    Rails.logger.error("Receipt parsing failed for check #{check.id}: #{error.message}")
    Rollbar.error(error, check_id: check.id) if defined?(Rollbar)
    check.broadcast_refresh
  rescue => e
    # Never let failure-handling itself strand the check or crash the worker.
    Rails.logger.error("Could not record parse failure for check #{check&.id}: #{e.message}")
  end

  def perform(check)
    # Idempotency: a retry (or at-least-once redelivery) after a successful
    # parse must not append a second copy of every line item.
    return if check.reviewing? || check.finalized?

    reasoning_text = +""
    parser = ReceiptParser.new(check.receipt_image_urls)
    parsed_data = parser.parse do |event_type, data|
      if event_type == :reasoning
        reasoning_text << data
        broadcast_reasoning(check, reasoning_text)
      end
    end

    check.transaction do
      check.line_items.destroy_all
      check.global_fees.destroy_all
      check.global_discounts.destroy_all

      check.update!(
        reasoning: reasoning_text,
        restaurant_name: parsed_data[:restaurant_name],
        restaurant_address: parsed_data[:restaurant_address],
        restaurant_phone_number: parsed_data[:restaurant_phone_number],
        billed_on: parsed_data[:billed_on],
        grand_total: parsed_data[:grand_total],
        currency: parsed_data[:currency],
        currency_symbol: parsed_data[:currency_symbol],
        status: "reviewing",
        line_items_attributes: parsed_data[:line_items_attributes],
        global_fees_attributes: parsed_data[:global_fees_attributes],
        global_discounts_attributes: parsed_data[:global_discounts_attributes]
      )
    end

    check.broadcast_refresh
  rescue *TRANSIENT_ERRORS
    raise # hand off to retry_on
  rescue => error
    self.class.mark_failed(check, error)
  end

  private

  def broadcast_reasoning(check, reasoning_text)
    html = ActionController::Base.helpers.sanitize(
      Kramdown::Document.new(reasoning_text).to_html
    )
    Turbo::StreamsChannel.broadcast_update_to(check, target: "reasoning_text", html: html)
  rescue => e
    # A dropped cable connection must not abort (and thus retry) the parse.
    Rails.logger.warn("Reasoning broadcast failed for check #{check.id}: #{e.message}")
  end
end
