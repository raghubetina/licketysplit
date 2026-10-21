module ReceiptEval
  # Parses each fixture `runs` times with one model configuration, several at
  # a time, and records how every attempt scored and what it cost in time and
  # tokens. One run per receipt is not enough to compare configurations: the
  # same model reads the same receipt differently from run to run.
  class Runner
    Attempt = Data.define(:fixture_id, :run, :result, :seconds, :usage, :tool_calls, :parse, :error) do
      def passed? = error.nil? && result.passed?
    end

    # Production retries the same transient failures (ParseReceiptJob), so an
    # eval that scored them as misreads would penalize a configuration for the
    # network rather than for how it reads.
    TRIES = 3

    def initialize(fixtures:, model:, reasoning_effort:, service_tier:, runs:, concurrency:)
      @fixtures = fixtures
      @model = model
      @reasoning_effort = reasoning_effort
      @service_tier = service_tier
      @runs = runs
      @concurrency = concurrency
    end

    def call(&on_attempt)
      uploads = []
      @fixtures.each { |fixture| uploads << [fixture, fixture.upload] }
      jobs = uploads.flat_map do |fixture, files|
        (1..@runs).map { |run| [fixture, files.map(&:last), run] }
      end

      parallel_map(jobs) do |fixture, inputs, run|
        attempt(fixture, inputs, run).tap { |result| on_attempt&.call(result) }
      end
    ensure
      Fixture.destroy_uploads(uploads.flat_map { |_, files| files.map(&:first) })
    end

    private

    def attempt(fixture, inputs, run)
      tries = 0
      begin
        parser = ReceiptParser.new(inputs, model: @model, reasoning_effort: @reasoning_effort, service_tier: @service_tier)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        parse = parser.parse
        seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      rescue *ParseReceiptJob::TRANSIENT_ERRORS
        retry if (tries += 1) < TRIES
        raise
      end

      Attempt.new(
        fixture_id: fixture.id, run:, result: Scorer.new(fixture.label, parse).score, seconds:,
        usage: usage(parser.response), tool_calls: tool_calls(parser.response), parse:, error: nil
      )
    rescue => e
      # One failed call should cost one attempt, not the whole sweep.
      Attempt.new(
        fixture_id: fixture.id, run:, result: nil, seconds: nil, usage: nil, tool_calls: nil, parse: nil,
        error: "#{e.class}: #{e.message}"
      )
    end

    def usage(response)
      {
        input: response.usage.input_tokens,
        output: response.usage.output_tokens,
        reasoning: response.usage.output_tokens_details&.reasoning_tokens
      }
    end

    def tool_calls(response)
      response.output.map(&:type).reject { |type| %i[message reasoning].include?(type) }.tally
    end

    def parallel_map(items)
      queue = Queue.new
      items.each_with_index { |item, index| queue << [item, index] }
      results = Array.new(items.size)

      workers = Array.new([@concurrency, items.size].min) do
        Thread.new do
          Rails.application.executor.wrap do
            loop do
              item, index = queue.pop(true)
              results[index] = yield(item)
            end
          rescue ThreadError
            # queue drained
          end
        end
      end
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads { workers.each(&:join) }

      results
    end
  end
end
