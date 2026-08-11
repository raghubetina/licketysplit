class SweepStrandedChecksJob < ApplicationJob
  queue_as :default

  StrandedParseError = Class.new(StandardError)

  # ParseReceiptJob can only mark its own check failed while it is running. When
  # the worker process itself dies, SolidQueue moves the claimed job straight to
  # solid_queue_failed_executions -- no retry, and no hook the job can use -- so
  # the check keeps showing a spinner forever. Sweep those back to "failed",
  # which is a state the show page offers a retry from.
  def perform
    Check.stranded_in_parsing.find_each do |check|
      ParseReceiptJob.mark_failed(
        check,
        StrandedParseError.new(
          "Parse was stranded in \"parsing\" since #{check.updated_at.iso8601}; " \
          "the worker running it most likely died mid-job"
        )
      )
    end
  end
end
