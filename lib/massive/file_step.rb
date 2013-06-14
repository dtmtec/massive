module Massive
  class FileStep < Step
    calculates_total_count_with { file.processor.total_count }

    delegate :file, to: :process
  end
end
