require "spec_helper"

describe Massive::Step do
  include_context "frozen time"
  include_context "stubbed memory_consumption"

  let(:process) { Massive::Process.new }
  subject(:step) { process.steps.build }

  describe ".perform" do
    before do
      Massive::Process.stub(:find_step).with(process.id, step.id).and_return(step)
    end

    it "finds the step and calls work on it" do
      step.should_receive(:work)
      Massive::Step.perform(process.id, step.id)
    end
  end

  describe ".queue" do
    it "should be massive_step" do
      Massive::Step.queue.should eq(:massive_step)
    end
  end

  describe ".calculate_total_count_with" do
    after { Massive::Step.calculates_total_count_with { 0 } }

    it "defaults to return 0" do
      step.calculate_total_count.should be_zero
    end

    it "defines the calculate_total_count method, which returns the returned value of the given block" do
      Massive::Step.calculates_total_count_with { 1234 }
      Massive::Step.new.calculate_total_count.should eq(1234)
    end
  end

  describe "#enqueue" do
    it "enqueues itself, passing ids as strings" do
      Resque.should_receive(:enqueue).with(step.class, step.process.id.to_s, step.id.to_s)
      step.enqueue
    end

    context "when a subclass redefines calculate_total_count" do
      subject(:step) { CustomStep.new }
      before { process.steps << step }

      it "enqueues itself, passing ids as strings" do
        Resque.should_receive(:enqueue).with(step.class, step.process.id.to_s, step.id.to_s)
        step.enqueue
      end
    end
  end

  describe "#start!" do
    it "persists the total_count" do
      step.start!
      step.reload.total_count.should be_present
    end

    it "sends a :start notification" do
      step.should_receive(:notify).with(:start)
      step.start!
    end

    context "when total_count is not defined" do
      it "updates it to zero" do
        step.start!
        step.total_count.should be_zero
      end
    end

    context "when total_count is defined" do
      before { step.total_count = 10 }

      it "does not change it" do
        expect { step.start! }.to_not change(step, :total_count)
      end
    end

    context "when a subclass redefines calculate_total_count" do
      subject(:step) { CustomStep.new }
      before { process.steps << step }

      context "and the total_count is not defined" do
        it "updates it to the return value of calculate_total_count" do
          step.start!
          step.total_count.should eq(step.send(:calculate_total_count))
        end
      end

      context "when total_count is defined" do
        context "and it is 0" do
          before { step.total_count = 0 }

          it "does not change it" do
            expect { step.work }.to_not change(step, :total_count)
          end
        end

        context "and it is 10" do
          before { step.total_count = 10 }

          it "does not change it" do
            expect { step.work }.to_not change(step, :total_count)
          end
        end
      end
    end
  end

  describe "#work" do
    it "starts the step, then process it" do
      step.should_receive(:start!) do
        step.should_receive(:process_step)
      end

      step.work
    end

    it "calls complete after processing step" do
      step.should_receive(:process_step) do
        step.should_receive(:complete)
      end

      step.work
    end
  end

  describe "jobs completion" do
    context "when it is not persisted" do
      it "does not reloads itself" do
        step.should_not_receive(:reload)
        step.completed_all_jobs?
      end
    end

    context "when it is persisted" do
      before { step.save }

      it "reloads itself, so that it can get the latest information" do
        step.should_receive(:reload).and_return(step)
        step.completed_all_jobs?
      end
    end

    context "when there are no jobs" do
      it { should be_completed_all_jobs }
    end

    context "when there are jobs" do
      let!(:jobs) { step.jobs = 3.times.map { |i| Massive::Job.new } }

      before do
        jobs.each { |job| job.stub(:completed?).and_return(true) }
      end

      context "but there is at least one that is not completed" do
        before do
          jobs.each { |job| job.stub(:completed?).and_return(true) }

          jobs.last.stub(:completed?).and_return(false)
        end

        it { should_not be_completed_all_jobs }
      end

      context "and all jobs are completed" do
        before do
          jobs.each { |job| job.stub(:completed?).and_return(true) }
        end

        it { should be_completed_all_jobs }
      end
    end
  end

  describe "#complete" do
    context "when there is at least one job that is not completed" do
      before { step.stub(:completed_all_jobs?).and_return(false) }

      it "does not updates the finished_at" do
        step.complete
        step.finished_at.should be_nil
      end

      it "does not updates the memory_consumption" do
        step.complete
        step.memory_consumption.should be_zero
      end

      it "does not persists the step" do
        step.should_not be_persisted
      end

      it "does not send a :complete notification" do
        step.should_not_receive(:notify).with(:complete)
        step.complete
      end

      context "when it should not execute next after completion" do
        it "does not enqueues next step of process" do
          process.should_not_receive(:enqueue_next)
          step.complete
        end
      end

      context "when it should execute next after completion" do
        before { step.execute_next = true }

        it "does not enqueues next step of process" do
          process.should_not_receive(:enqueue_next)
          step.complete
        end
      end
    end

    context "when all jobs are completed" do
      let(:lock_key) { step.send(:lock_key_for, :complete) }

      let(:redis) { Resque.redis }

      before { step.stub(:completed_all_jobs?).and_return(true) }

      before { redis.flushdb }
      after  { redis.flushdb }

      context "but there is a complete lock for this step" do
        before do
          redis.set(lock_key, 1.minute.from_now)
        end

        it "does not updates the finished_at" do
          step.complete
          step.finished_at.should be_nil
        end

        it "does not updates the memory_consumption" do
          step.complete
          step.memory_consumption.should be_zero
        end

        it "does not persists the step" do
          step.should_not be_persisted
        end

        it "does not send a :complete notification" do
          step.should_not_receive(:notify).with(:complete)
          step.complete
        end

        context "when it should not execute next after completion" do
          it "does not enqueues next step of process" do
            process.should_not_receive(:enqueue_next)
            step.complete
          end
        end

        context "when it should execute next after completion" do
          before { step.execute_next = true }

          it "does not enqueues next step of process" do
            process.should_not_receive(:enqueue_next)
            step.complete
          end
        end
      end

      context "but there is no complete lock for this step" do
        it "updates the finished_at with the current time, persisting it" do
          step.complete
          step.reload.finished_at.to_i.should eq(now.to_i)
        end

        it "updates the memory_consumption, persisting it" do
          step.complete
          step.reload.memory_consumption.should eq(current_memory_consumption)
        end

        it "sends a :complete notification" do
          step.should_receive(:notify).with(:complete)
          step.complete
        end

        context "when it should not execute next after completion" do
          it "does not enqueues next step of process" do
            process.should_not_receive(:enqueue_next)
            step.complete
          end
        end

        context "when it should execute next after completion" do
          before { step.execute_next = true }

          it "enqueues next step of process" do
            process.should_receive(:enqueue_next)
            step.complete
          end
        end
      end
    end
  end

  context "#process_step" do
    context "when total_count is zero" do
      before { step.total_count = 0 }

      it "creates no jobs" do
        step.process_step
        step.jobs.should be_empty
      end
    end

    context "when total_count is 2000" do
      before { step.total_count = 2000 }

      let(:limit) { 100 }

      it "creates 20 jobs, each processing 100 items" do
        step.process_step
        step.jobs.each_with_index do |job, index|
          job.limit.should eq(limit)
          job.offset.should eq(index * limit)
        end
      end

      it "creates jobs of the Massive::Job class" do
        step.process_step
        step.jobs.each do |job|
          job.should be_an_instance_of(Massive::Job)
        end
      end

      context "on custom step class" do
        subject(:step) { CustomStep.new }
        before { process.steps << step }
        let(:limit) { 1000 }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            job.limit.should eq(limit)
            job.offset.should eq(index * limit)
          end
        end

        it "creates jobs of the redefined job_class" do
          step.process_step
          step.jobs.each do |job|
            job.should be_an_instance_of(CustomJob)
          end
        end
      end

      context "on a inherited step, that didn't redefine any configuration" do
        subject(:step) { InheritedStep.new }
        before { process.steps << step }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            job.limit.should eq(limit)
            job.offset.should eq(index * limit)
          end
        end

        it "creates jobs of the Massive::Job" do
          step.process_step
          step.jobs.each do |job|
            job.should be_an_instance_of(Massive::Job)
          end
        end
      end
    end

    context "when total_count is 3000" do
      before { step.total_count = 3000 }

      let(:limit) { 1000 }

      it "creates 3 jobs, each processing 1000 items" do
        step.process_step
        step.jobs.each_with_index do |job, index|
          job.limit.should eq(limit)
          job.offset.should eq(index * limit)
        end
      end

      context "on custom step class" do
        subject(:step) { CustomStep.new }
        before { process.steps << step }
        let(:limit) { 1500 }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            job.limit.should eq(limit)
            job.offset.should eq(index * limit)
          end
        end

        it "creates jobs of the redefined job_class" do
          step.process_step
          step.jobs.each do |job|
            job.should be_an_instance_of(CustomJob)
          end
        end
      end

      context "on a inherited step, that didn't redefine any configuration" do
        subject(:step) { InheritedStep.new }
        before { process.steps << step }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            job.limit.should eq(limit)
            job.offset.should eq(index * limit)
          end
        end

        it "creates jobs of the Massive::Job" do
          step.process_step
          step.jobs.each do |job|
            job.should be_an_instance_of(Massive::Job)
          end
        end
      end
    end
  end

  describe "processed items and time" do
    context "when the step has no jobs" do
      its(:processed)            { should be_zero }
      its(:processed_percentage) { should be_zero }
      its(:processing_time)      { should be_zero }
    end

    context "when the step has jobs with processed itens" do
      let!(:jobs) { step.jobs = 3.times.map { |i| Massive::Job.new(processed: 100 * i) } }
      let(:total_processed) { jobs.map(&:processed).sum }

      its(:processed) { should eq(total_processed) }

      context "and the total count is zero" do
        its(:processed_percentage) { should be_zero }
      end

      context "and the total count is greater than zero" do
        before { step.total_count = 1000 }

        its(:processed_percentage) { should eq(total_processed.to_f / step.total_count) }
      end
    end

    context "when the step has jobs that have some elapsed time" do
      let!(:jobs) do
        step.jobs = 3.times.map do |i|
          Massive::Job.new.tap { |j| j.stub(:elapsed_time).and_return(100 * i) }
        end
      end

      let(:total_elapsed_time) { jobs.map(&:elapsed_time).sum }

      its(:processing_time) { should eq(total_elapsed_time) }
    end
  end

  context "on a inherited step" do
    subject(:step) { InheritedStep.new }
    before { process.steps << step }

    it "properly sets the _type" do
      step._type.should be_present
    end
  end
end
