module Massive
  class FileJob < Job
    delegate :file, to: :step

    def each_item(&block)
      file.processor.process_range(offset: offset + processed, limit: limit - processed, &block)
    end
  end
end
