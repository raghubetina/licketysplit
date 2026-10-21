module ReceiptEval
  # Compares a parse with a receipt's verified label on what decides who pays
  # what. Only :placement depends on how lines are grouped; the rest compare
  # amounts, so a parse that names items differently or prints a quantity as
  # two identical lines is not penalized.
  class Scorer
    Result = Data.define(:checks, :details) do
      def passed? = checks.values.all?

      def failed = checks.reject { |_, ok| ok }.keys

      def report
        failed.map { |check| "#{check}: #{details.fetch(check)}" }.join("\n")
      end
    end

    # What the app bills: Check#calculated_total over unsaved attributes.
    def self.billed_total(attributes)
      lines = attributes[:line_items_attributes].sum do |item|
        net_amount(item) + Array(item[:addons_attributes]).sum { |addon| net_amount(addon) }
      end
      fees = attributes[:global_fees_attributes].sum { |fee| fee[:amount].to_f }
      discounts = attributes[:global_discounts_attributes].sum { |discount| discount[:amount].to_f }

      (lines + fees - discounts).round(2)
    end

    def self.net_amount(row)
      row[:unit_price].to_f * row[:quantity].to_i - row[:discount].to_f
    end

    def initialize(label, parse)
      @label = label
      @parse = parse
    end

    def score
      checks = {}
      details = {}

      compare = ->(name, expected, actual) do
        checks[name] = expected == actual
        details[name] = describe(expected, actual)
      end

      compare.call(:total, cents(@label[:grand_total]), cents(self.class.billed_total(@parse)))
      compare.call(:grand_total, cents(@label[:grand_total]), cents(@parse[:grand_total]))
      compare.call(:prices, prices(@label), prices(@parse))
      compare.call(:pairing, [], mispaired_prices)
      compare.call(:discounts, discounts(@label), discounts(@parse))
      compare.call(:fees, fees(@label), fees(@parse))
      label_parents, parse_parents = parent_keys
      compare.call(:placement, placements(@label, label_parents), placements(@parse, parse_parents))

      Result.new(checks:, details:)
    end

    private

    def cents(amount) = (amount.to_f * 100).round

    def rows(attributes)
      attributes[:line_items_attributes].flat_map { |item| [item, *Array(item[:addons_attributes])] }
    end

    # Each priced row with what it charges per unit of its line item. An
    # addon's charge is spread over its parent's quantity: "extra chile 0.70"
    # on two sandwiches bills 0.35 a sandwich whether it is written 1 x 0.70
    # or 2 x 0.35, and a 20.00 spirit on each of two cocktails is the same
    # charge as an addon or as its own line.
    def per_unit_rows(attributes)
      attributes[:line_items_attributes].flat_map do |item|
        quantity = item[:quantity].to_i
        addons = Array(item[:addons_attributes]).map do |addon|
          {row: addon, per_unit: Rational(cents(addon[:unit_price]) * addon[:quantity].to_i, quantity), units: quantity}
        end

        [{row: item, per_unit: Rational(cents(item[:unit_price])), units: quantity}, *addons]
      end
    end

    def format_cents(amount) = (amount.denominator == 1) ? amount.to_i.to_s : amount.to_f.round(1).to_s

    # Every priced unit on the receipt, line items and addons alike.
    def prices(attributes)
      per_unit_rows(attributes)
        .flat_map { |entry| [entry[:per_unit]] * entry[:units] }
        .select(&:positive?)
        .sort
        .map { |amount| format_cents(amount) }
    end

    # Prices that landed on the wrong item. The amounts can all be present yet
    # shifted a line, as when a receipt prints each price a row above its
    # name, so each priced label row is matched to the parsed row with the
    # most similar description (an equal price, then nearby position, breaking
    # ties between identical names) and their prices compared.
    def mispaired_prices
      expected = priced_rows(@label)
      actual = priced_rows(@parse)

      candidates = expected.each_with_index.flat_map do |label_row, i|
        actual.each_with_index.filter_map do |parse_row, j|
          similarity = similarity(label_row[:words], parse_row[:words])
          next if similarity.zero?

          [-similarity, (label_row[:cents] == parse_row[:cents]) ? 0 : 1, (i - j).abs, i, j]
        end
      end

      paired_expected = {}
      paired_actual = {}
      candidates.sort.each do |*, i, j|
        next if paired_expected.key?(i) || paired_actual.key?(j)

        paired_expected[i] = j
        paired_actual[j] = i
      end

      paired_expected.filter_map do |i, j|
        next if expected[i][:cents] == actual[j][:cents]

        "#{expected[i][:description]} #{expected[i][:cents]} read as #{actual[j][:cents]}"
      end
    end

    def priced_rows(attributes)
      per_unit_rows(attributes).filter_map do |entry|
        next unless entry[:per_unit].positive?

        description = entry[:row][:description]
        {description:, cents: format_cents(entry[:per_unit]), words: words(description)}
      end
    end

    def words(description) = description.to_s.downcase.scan(/[[:alnum:]]+/)

    def similarity(words, other)
      return 0.0 if words.empty? || other.empty?

      matched = words.count { |word| other.any? { |o| o == word || (word.size > 2 && o.size > 2 && (o.start_with?(word) || word.start_with?(o))) } }
      matched.to_f / [words.size, other.size].max
    end

    # Item and addon discounts per unit of their line item, as addon prices
    # are, so a quantity printed as two lines splits its comp the same way.
    def item_discounts(item)
      quantity = item[:quantity].to_i
      [item, *Array(item[:addons_attributes])].select { |row| row[:discount].to_f.positive? }.flat_map do |row|
        [Rational(cents(row[:discount]), quantity)] * quantity
      end
    end

    def discounts(attributes)
      (attributes[:line_items_attributes].flat_map { |item| item_discounts(item) } +
        attributes[:global_discounts_attributes].map { |discount| Rational(cents(discount[:amount])) })
        .select(&:positive?)
        .sort
        .map { |amount| format_cents(amount) }
    end

    # Names every unit of every line item after the label line item it reads
    # as, so two items can't trade addons or comps unnoticed however their
    # names read. Items are matched in receipt order -- the order labels follow and
    # the prompt asks for -- by aligning their units, so a quantity printed as
    # identical lines lines up unit for unit. An item a parse lists out of
    # order is left unmatched, which only matters if it carries an addon or
    # comp.
    def parent_keys
      label_items = @label[:line_items_attributes]
      parse_items = @parse[:line_items_attributes]
      label_keys = label_items.each_with_index.map { |item, i| "#{item[:description]} (line #{i + 1})" }
      label_units = units(label_items)
      parse_units = units(parse_items)

      matched = align(label_units, parse_units).to_h { |l, p| [p, label_units[l][:item]] }
      parse_keys = parse_units.each_with_index.map do |unit, p|
        matched.key?(p) ? label_keys[matched[p]] : "unmatched #{parse_items[unit[:item]][:description]}"
      end

      [per_item(label_units, label_units.map { |unit| label_keys[unit[:item]] }), per_item(parse_units, parse_keys)]
    end

    def per_item(units, keys)
      units.zip(keys).group_by { |unit, _| unit[:item] }.transform_values { |pairs| pairs.map(&:last) }
    end

    def units(items)
      items.each_with_index.flat_map do |item, i|
        [{item: i, words: words(item[:description]), price: cents(item[:unit_price])}] * item[:quantity].to_i
      end
    end

    # The order-preserving pairing of units with the highest total score.
    def align(left, right)
      best = Array.new(left.size + 1) { Array.new(right.size + 1, 0.0) }
      (left.size - 1).downto(0) do |a|
        (right.size - 1).downto(0) do |b|
          skip = [best[a + 1][b], best[a][b + 1]].max
          score = unit_score(left[a], right[b])
          best[a][b] = score ? [skip, score + best[a + 1][b + 1]].max : skip
        end
      end

      pairs = []
      a = b = 0
      while a < left.size && b < right.size
        score = unit_score(left[a], right[b])
        if score && best[a][b] == score + best[a + 1][b + 1]
          pairs << [a, b]
          a += 1
          b += 1
        elsif best[a][b] == best[a + 1][b]
          a += 1
        else
          b += 1
        end
      end
      pairs
    end

    # An equal price counts for more than a similar name, which is the weaker
    # evidence; units with neither don't pair at all.
    def unit_score(label_unit, parse_unit)
      similarity = similarity(label_unit[:words], parse_unit[:words])
      same_price = label_unit[:price] == parse_unit[:price]
      return if similarity.zero? && !same_price

      (same_price ? 2 : 0) + similarity
    end

    # Totals by type: tax printed as one line or as three splits the same way.
    def fees(attributes)
      attributes[:global_fees_attributes]
        .group_by { |fee| fee[:fee_type].to_s }
        .transform_values { |fees| fees.sum { |fee| cents(fee[:amount]) } }
        .reject { |_, cents| cents.zero? }
        .sort.map { |type, cents| "#{type} #{cents}" }
    end

    # Where money is attached: a priced addon under the wrong item, or a comp
    # on the wrong item or on the whole check, bills the wrong person even
    # when every amount is right.
    def placements(attributes, unit_parents)
      attached = attributes[:line_items_attributes].each_with_index.flat_map do |item, index|
        parents = unit_parents.fetch(index, [])
        quantity = item[:quantity].to_i
        addons = Array(item[:addons_attributes])

        priced_addons = addons.select { |addon| addon[:unit_price].to_f.positive? }.flat_map do |addon|
          per_unit = Rational(cents(addon[:unit_price]) * addon[:quantity].to_i, quantity)
          parents.map { |parent| "addon #{format_cents(per_unit)} under #{parent}" }
        end
        comps = [item, *addons].select { |row| row[:discount].to_f.positive? }.flat_map do |row|
          per_unit = Rational(cents(row[:discount]), quantity)
          parents.map { |parent| "discount #{format_cents(per_unit)} on #{parent}" }
        end

        priced_addons + comps
      end

      check_discounts = attributes[:global_discounts_attributes].map do |discount|
        "discount #{cents(discount[:amount])} on check"
      end

      (attached + check_discounts).sort
    end

    def describe(expected, actual)
      return "expected #{expected}, got #{actual}" unless expected.is_a?(Array)

      missing = multiset_difference(expected, actual)
      extra = multiset_difference(actual, expected)
      "missing #{missing.inspect}, extra #{extra.inspect}"
    end

    def multiset_difference(from, other)
      remaining = other.tally
      from.reject { |value| (remaining[value] = remaining.fetch(value, 0) - 1) >= 0 }
    end
  end
end
