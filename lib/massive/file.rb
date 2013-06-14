module Massive
  class File
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :process

    field :url,         type: String

    field :encoding,    type: String
    field :col_sep,     type: String
    field :total_count, type: Integer

    field :headers,     type: Array, default: -> { [] }
    field :sample_data, type: Array, default: -> { [] }

    def processor
      @processor ||= FileProcessor::CSV.new(url, processor_options)
    end

    def gather_info!
      clear_info

      self.encoding    = processor.detected_encoding
      self.col_sep     = processor.col_sep
      self.total_count = processor.total_count
      self.headers     = processor.shift && processor.headers

      processor.process_range(limit: 3) do |row|
        self.sample_data << row.fields
      end

      save
    end

    private

    def clear_info
      [:encoding, :col_sep, :total_count, :headers].each { |attr| self[attr] = nil }

      sample_data.clear
    end

    def processor_options
      {
        headers:  true,
        encoding: encoding,
        col_sep:  col_sep
      }
    end
  end
end
