module Massive
  class Job
    include Mongoid::Document
    include Mongoid::Timestamps

    include Massive::Status
    include Massive::MemoryConsumption
    include Massive::TimingSupport
    include Massive::Retry

    embedded_in :step, class_name: 'Massive::Step'

    field :processed,   type: Integer, default: 0
    field :offset,      type: Integer, default: 0
    field :limit,       type: Integer, default: -1

    delegate :process, :notify, to: :step

    define_model_callbacks :work

    after_create :enqueue

    def self.perform(process_id, step_id, job_id)
      Massive::Process.find_job(process_id, step_id, job_id).work
    end

    def self.queue
      :massive_job
    end

    def enqueue
      Resque.enqueue(self.class, process.id.to_s, step.id.to_s, id.to_s)
    end

    def work
      handle_errors do
        start!

        run_callbacks :work do
          each_item do |item, index|
            retrying do
              process_each(item, index)
              increment_processed
              notify(:progress)
            end
          end
        end

        finish!
      end
    end

    def finish!
      update_attributes(finished_at: Time.now, memory_consumption: current_memory_consumption)

      step.complete
    end

    def each_item(&block)
      # iterate through each item within offset/limit range
    end

    def process_each(item, index)
      # process an item
    end

    protected

    def attributes_to_reset
      super.merge(processed: 0)
    end

    private

    def handle_errors(&block)
      block.call
    rescue StandardError, SignalException => e
      step.failed_at = Time.now

      assign_attributes(
        last_error: e.message,
        failed_at: Time.now,
        processed: 0,
        retries: retries
      )

      step.save
      notify(:failed)

      raise e
    end

    def increment_processed
      inc(:processed, 1)
    end
  end
end
