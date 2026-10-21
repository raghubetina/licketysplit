namespace :receipts do
  desc "Score a parsing configuration against the receipt labels " \
       "(MODEL, EFFORT, TIER, RUNS=3, ONLY=1005,1086, CONCURRENCY=8)"
  task eval: :environment do
    fixtures = selected_fixtures
    model = ENV.fetch("MODEL", ReceiptParser::MODEL)
    effort = ENV.fetch("EFFORT", ReceiptParser::REASONING_EFFORT).to_sym
    tier = ENV.fetch("TIER", ReceiptParser::SERVICE_TIER).to_sym
    runs = Integer(ENV.fetch("RUNS", "3"))

    puts "#{model} (#{effort}, #{tier} tier) · #{runs} runs × #{fixtures.size} receipts · each run is a paid call"
    attempts = ReceiptEval::Runner.new(
      fixtures:, model:, reasoning_effort: effort, service_tier: tier, runs:, concurrency: Integer(ENV.fetch("CONCURRENCY", "8"))
    ).call do |attempt|
      outcome = attempt.error || (attempt.passed? ? "pass" : attempt.result.failed.join(", "))
      seconds = attempt.seconds ? format("%.1fs", attempt.seconds) : "-"
      puts format("  %-6s run %d  %6s  %s", attempt.fixture_id, attempt.run, seconds, outcome)
    end

    summarize(model, "#{effort}-#{tier}", attempts)
  end

  desc "Draft labels for receipts into tmp/receipt_label_drafts for checking by hand " \
       "(ONLY=2001,2002, MODEL, EFFORT)"
  task draft_labels: :environment do
    out_dir = Rails.root.join("tmp/receipt_label_drafts")
    FileUtils.mkdir_p(out_dir)
    model = ENV.fetch("MODEL", ReceiptParser::MODEL)
    effort = ENV.fetch("EFFORT", ReceiptParser::REASONING_EFFORT).to_sym

    ENV.fetch("ONLY").split(",").each do |id|
      fixture = ReceiptEval::Fixture.new(id)
      parse = fixture.with_parser_inputs { |inputs| ReceiptParser.new(inputs, model:, reasoning_effort: effort).parse }
      File.write(out_dir.join("#{id}_parsed.json"), JSON.pretty_generate(parse) + "\n")

      comparison = if File.exist?(fixture.label_path)
        result = ReceiptEval::Scorer.new(fixture.label, parse).score
        result.passed? ? "matches the label" : "differs from the label:\n#{result.report}"
      else
        "no label yet"
      end
      puts "#{id}: #{Pathname(out_dir).join("#{id}_parsed.json").relative_path_from(Rails.root)} -- #{comparison}"
    end

    puts "A draft is a model's reading, not a label. Check every amount and line " \
         "against the receipt before copying one into spec/fixtures/parsed_receipts."
  end

  def selected_fixtures
    all = ReceiptEval::Fixture.labeled
    return all unless ENV["ONLY"]

    ids = ENV["ONLY"].split(",")
    all.select { |fixture| ids.include?(fixture.id) }
  end

  def summarize(model, effort, attempts)
    scored = attempts.reject(&:error)
    passed = attempts.count(&:passed?)
    seconds = scored.map(&:seconds).sort
    percentile = ->(p) { seconds.empty? ? 0 : seconds[((seconds.size - 1) * p).round] }

    puts
    puts format("passed %d/%d (%.0f%%)", passed, attempts.size, 100.0 * passed / attempts.size)
    puts "failed checks: #{scored.flat_map { |attempt| attempt.result.failed }.tally.sort_by { -_2 }.to_h}"
    puts "errors: #{attempts.count(&:error)}" if attempts.any?(&:error)
    puts format("seconds: p50 %.1f · p90 %.1f · max %.1f", percentile.call(0.5), percentile.call(0.9), seconds.max.to_f)
    %i[input output reasoning].each do |kind|
      counts = scored.filter_map { |attempt| attempt.usage[kind] }
      puts format("%s tokens: mean %d", kind, counts.sum / [counts.size, 1].max)
    end
    puts "tool calls: #{scored.map(&:tool_calls).reduce({}) { |sum, calls| sum.merge(calls) { _2 + _3 } }}"

    attempts.group_by(&:fixture_id).sort.each do |id, runs|
      next if runs.all?(&:passed?)

      failures = runs.reject(&:passed?).map { |attempt| attempt.error || attempt.result.failed.join("+") }
      puts format("  %-6s %d/%d  %s", id, runs.count(&:passed?), runs.size, failures.tally.map { "#{_1} ×#{_2}" }.join(", "))
    end

    path = Rails.root.join("tmp/receipt_evals/#{Time.current.strftime("%Y%m%d-%H%M%S")}-#{model}-#{effort}.json")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(
      model:, effort:, attempts: attempts.map { |attempt|
        attempt.to_h.except(:result).merge(
          passed: attempt.passed?, failed: attempt.result&.failed, details: attempt.result&.details
        )
      }
    ) + "\n")
    puts "details: #{path.relative_path_from(Rails.root)}"
  end
end
