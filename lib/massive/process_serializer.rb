module Massive
  class ProcessSerializer < ActiveModel::Serializer
    attributes :id, :created_at, :updated_at, :processed_percentage
    attributes completed?: :completed, failed?: :failed
    attributes cancelled?: :cancelled, in_progress?: :in_progress

    has_one :file
    has_many :steps

    def id
      object.id.to_s
    end

    def include_file?
      object.respond_to?(:file)
    end
  end
end
