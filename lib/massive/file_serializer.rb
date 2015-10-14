module Massive
  class FileSerializer < ActiveModel::Serializer
    attributes :id, :url, :encoding, :col_sep, :total_count, :use_headers,
               :headers, :sample_data, :file_size

    def id
      object.id.to_s
    end
  end
end
