module ApplicationHelper
  # Deterministically maps a participant (or any record) to one of the 8
  # pastel palette classes (.ls-p-1 through .ls-p-8) defined in _redesign.scss.
  # Uses the record id so the color is stable across renders.
  def participant_color_class(record)
    return "ls-p-1" unless record&.id

    digest = Digest::MD5.hexdigest(record.id.to_s)
    index = (digest.to_i(16) % 8) + 1
    "ls-p-#{index}"
  end

  # Single-letter avatar from a name. Falls back to '?'.
  def participant_initial(record)
    record&.name.to_s.strip[0]&.upcase || "?"
  end
end
