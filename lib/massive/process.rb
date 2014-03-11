module Massive
  class Process
    include Mongoid::Document
    include Mongoid::Timestamps

    embeds_many :steps, class_name: 'Massive::Step'

    def self.find_step(process_id, step_id)
      find(process_id).steps.find(step_id)
    end

    def self.find_job(process_id, step_id, job_id)
      find_step(process_id, step_id).jobs.find(job_id)
    end

    def enqueue_next
      steps.not_completed.first.try(:enqueue)
    end

    def processed_percentage
      total_weight > 0 ? total_steps_processed_percentage.to_f / total_weight : 0
    end

    def completed?
      steps.not_completed.none?
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
