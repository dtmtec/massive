module Massive
  class Process
    include Mongoid::Document
    include Mongoid::Timestamps

    field :cancelled_at, type: Time

    has_many :steps, class_name: 'Massive::Step', dependent: :destroy

    def self.find_step(process_id, step_id)
      find(process_id).steps.find(step_id)
    end

    def self.find_job(process_id, step_id, job_id)
      find_step(process_id, step_id).jobs.find(job_id)
    end

    def enqueue_next
      next_step.try(:enqueue)
    end

    def next_step
      step = steps.not_completed.not_started.first
      step.try(:enqueued?) ? nil : step
    end

    def processed_percentage
      total_weight > 0 ? total_steps_processed_percentage.to_f / total_weight : 0
    end

    def completed?
      steps.not_completed.none?
    end

    def failed?
      steps.any? { |step| step.failed_at? }
    end

    def cancelled?
      cancelled_at? || redis.exists(cancelled_key)
    end

    def cancel
      self.cancelled_at = Time.now
      redis.setex(cancelled_key, 1.day, true)
      save
    end

    def active_model_serializer
      super || Massive::ProcessSerializer
    end

    protected
      def redis
        Massive.redis
      end

      def cancelled_key
        "#{self.class.name.underscore}:#{id}:cancelled"
      end

    private
      def total_weight
        steps.map(&:weight).sum
      end

      def total_steps_processed_percentage
        steps.inject(0) do |result, step|
          result += step.processed_percentage * step.weight
        end
      end
  end
end
