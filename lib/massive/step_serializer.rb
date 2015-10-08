module Massive
  class StepSerializer < ActiveModel::Serializer
    attributes :id, :created_at, :updated_at, :started_at, :finished_at, :failed_at,
               :last_error, :retries, :memory_consumption, :total_count,
               :processed, :processed_percentage, :processing_time, :elapsed_time,
               :notifier_id

    has_one :file

    def id
      object.id.to_s
    end

    def include_file?
      object.respond_to?(:file)
    end
  end
end
