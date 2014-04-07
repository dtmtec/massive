module Massive
  class Step
    include Mongoid::Document
    include Mongoid::Timestamps

    include Massive::Status
    include Massive::MemoryConsumption
    include Massive::TimingSupport
    include Massive::Locking
    include Massive::Notifications

    embedded_in :process, class_name: 'Massive::Process'
    embeds_many :jobs,    class_name: 'Massive::Job'

    field :total_count,  type: Integer
    field :weight,       type: Integer, default: 1
    field :job_class,    type: String,  default: -> { self.class.job_class }
    field :execute_next, type: Boolean, default: false

    define_model_callbacks :work
    define_model_callbacks :complete

    def self.perform(process_id, step_id)
      Massive::Process.find_step(process_id, step_id).work
    end

    def self.queue
      :massive_step
    end

    def self.calculates_total_count_with(&block)
      define_method(:calculate_total_count, &block)
    end

    def self.limit_ratio(value=nil)
      @limit_ratio = value if value
      @limit_ratio
    end

    def self.job_class(value=nil)
      @job_class = value if value
      @job_class
    end

    def self.inherited(child)
      super

      child.job_class   self.job_class
      child.limit_ratio self.limit_ratio
    end

    limit_ratio 3000 => 1000, 0 => 100
    job_class 'Massive::Job'

    def enqueue
      Resque.enqueue(self.class, process.id.to_s, id.to_s)
      notify(:enqueued)
    end

    def start!
      super
      notify(:start)
    end

    def work
      start!

      run_callbacks :work do
        process_step
      end

      complete
    end

    def process_step
      self.jobs = number_of_jobs.times.map do |index|
        job_class.constantize.new(job_params(index))
      end
    end

    def complete
      if completed_all_jobs? && !locked?(:complete)
        run_callbacks :complete do
          update_attributes finished_at: Time.now, failed_at: nil, memory_consumption: current_memory_consumption
          notify(:complete)
        end

        process.enqueue_next if execute_next?
      end
    end

    def completed_all_jobs?
      reload if persisted?

      jobs.all?(&:completed?)
    end

    def processed
      jobs.map(&:processed).sum
    end

    def processed_percentage
      total_count && total_count > 0 ? processed.to_f / total_count : 0
    end

    def processing_time
      jobs.map(&:elapsed_time).sum
    end

    def limit
      @limit ||= self.class.limit_ratio.find { |count, l| total_count >= count }.last
    end

    def calculate_total_count
      0
    end

    def active_model_serializer
      super || Massive::StepSerializer
    end

    protected

    def job_params(index)
      {
        offset: index * limit,
        limit: limit,
        step: self
      }
    end

    def number_of_jobs
      (total_count.to_f / limit).ceil
    end

    def attributes_to_reset
      super.merge(total_count: total_count || calculate_total_count)
    end

    def args_for_resque
      [process.id.to_s, id.to_s]
    end
  end
end
