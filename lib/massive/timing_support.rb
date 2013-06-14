module Massive
  module TimingSupport
    def elapsed_time
      start  = started_at || 0
      finish = finished_at || Time.now

      started_at? ? finish - start : 0
    end
  end
end
