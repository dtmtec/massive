module Massive
  class File
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :process

    field :url,         type: String
    field :filename,    type: String

    field :encoding,    type: String
    field :col_sep,     type: String
    field :total_count, type: Integer
    field :use_headers, type: Boolean, default: true

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
      self.headers     = processor.shift && processor.headers if use_headers?

      processor.process_range(limit: 3) do |row|
        self.sample_data << row.fields
      end

      save
    end

    def url
      read_attribute(:url).presence || authenticated_url
    end

    private

    def clear_info
      [:encoding, :col_sep, :total_count, :headers].each { |attr| self[attr] = nil }

      sample_data.clear
    end

    def processor_options
      {
        headers:  use_headers?,
        encoding: encoding,
        col_sep:  col_sep
      }
    end

    def authenticated_url
      if can_use_fog?
        fog_file.respond_to?(:url) ? fog_file.url(Massive.fog_authenticated_url_expiration) : fog_file.public_url
      end
    end

    def can_use_fog?
      filename && Massive.fog_credentials.present?
    end

    def fog_connection
      @fog_connection ||= Fog::Storage.new(Massive.fog_credentials)
    end

    def fog_directory
      @fog_directory ||= fog_connection.directories.get(Massive.fog_directory)
    end

    def fog_file
      @fog_file ||= fog_directory.files.get(filename)
    end
  end
end
