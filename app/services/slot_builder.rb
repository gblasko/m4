class SlotBuilder
  # Returns an array of slot hashes for a given location/date/step.
  # Each slot: { time:, label:, count:, full:, past: }
  # - count: # of open requests scheduled in the same hour bucket
  # - full:  count >= location.soft_cap_per_hour (still bookable, just busy)
  # - past:  slot is earlier than the lead-time cutoff (must be hidden/disabled)
  def self.call(location:, date:, step_minutes: 30)
    range = location.open_range_on(date)
    return [] unless range

    hourly_counts = location.slot_counts_for(date) # keyed by hour-bucket Time
    lead_cutoff = Request::LEAD_TIME.from_now
    step = step_minutes.minutes

    slots = []
    cur = range.first
    while cur + step <= range.last + 1.second # include slots that end exactly at close
      hour_bucket = cur.in_time_zone(location.timezone).beginning_of_hour
      count = hourly_counts[hour_bucket] || 0
      slots << {
        time: cur.iso8601,
        label: cur.in_time_zone(location.timezone).strftime("%l:%M %p").strip,
        count: count,
        full: count >= location.soft_cap_per_hour,
        past: cur < lead_cutoff
      }
      cur += step
    end
    slots
  end

  # First date in the window with at least one bookable (non-past) slot,
  # so a customer hitting the form at 6pm doesn't get an empty "today" grid.
  def self.first_bookable_date(location:, min_date:, max_date:, step_minutes: 30)
    (min_date..max_date).each do |d|
      slots = call(location: location, date: d, step_minutes: step_minutes)
      return d if slots.any? { |s| !s[:past] }
    end
    min_date
  end
end
