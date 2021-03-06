module Massive
  class Job
    include Mongoid::Document
    include Mongoid::Timestamps

    include Massive::Status
    include Massive::MemoryConsumption
    include Massive::TimingSupport
    include Massive::Retry
    include Massive::Cancelling

    embedded_in :step, class_name: 'Massive::Step'

    field :processed,   type: Integer, default: 0
    field :offset,      type: Integer, default: 0
    field :limit,       type: Integer, default: -1

    delegate :process, :notify, to: :step

    define_model_callbacks :work

    after_create :enqueue

    def self.queue
      if split_jobs
        :"#{queue_prefix}_#{Kernel.rand(split_jobs) + 1}"
      else
        queue_prefix
      end
    end

    def self.queue_prefix(value=nil)
      @queue_prefix = value if !value.nil?
      @queue_prefix || :massive_job
    end

    def self.split_jobs(value=nil)
      @split_jobs = value if !value.nil?
      @split_jobs.nil? ? Massive.split_jobs : @split_jobs
    end

    def self.cancel_when_failed(value=nil)
      @cancel_when_failed = value if !value.nil?
      @cancel_when_failed
    end

    def enqueue
      update_attributes(enqueued_at: Time.now)
      Massive::Worker.set(queue: self.class.queue).perform_later(step.id.to_s, id.to_s)
    end

    def work
      handle_errors do
        cancelling do
          start!

          run_callbacks :work do
            each_item do |item, index|
              retrying do
                cancelling do
                  process_each(item, index)

                  begin
                    increment_processed
                    notify(:progress)
                  rescue StandardError
                  end
                end
              end
            end
          end

          finish!
        end
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

    def cancelled?
      process.cancelled?
    end

    private

    def handle_errors(&block)
      block.call
    rescue Massive::Cancelled => e
      assign_attributes(cancelled_at: Time.now)
      step.update_attributes(cancelled_at: Time.now)

      notify(:cancelled)
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

      process.cancel if self.class.cancel_when_failed
      raise e
    end

    def increment_processed
      inc(processed: 1)
    end
  end
end
