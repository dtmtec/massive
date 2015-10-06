module Massive
  class Worker < ::ActiveJob::Base
    queue_as :massive

    def perform(*arguments)
      worker(*arguments).work
    end

    def worker(step_id, job_id=nil)
      step = Massive::Step.find(step_id)
      worker = job_id.nil? ? step : step.jobs.find(job_id)
    end
  end
end
