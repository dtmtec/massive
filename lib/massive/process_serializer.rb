module Massive
  class ProcessSerializer < ActiveModel::Serializer
    attributes :id, :created_at, :updated_at, :processed_percentage
    attribute :completed?, key: :completed

    has_many :steps

    def id
      object.id.to_s
    end
  end
end
