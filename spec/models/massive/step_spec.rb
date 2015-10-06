require "spec_helper"

describe Massive::Step do
  include_context "frozen time"
  include_context "stubbed memory_consumption"

  let(:process) { Massive::Process.new }
  subject(:step) { process.steps.build }

  before { allow(step).to receive(:process).and_return(process) }

  describe ".queue" do
    it "should be a massive_step" do
      expect(Massive::Step.queue).to eq(:massive_step)
    end
  end

  describe ".calculate_total_count_with" do
    after { Massive::Step.calculates_total_count_with { 0 } }

    it "defaults to return 0" do
      expect(step.calculate_total_count).to be_zero
    end

    it "defines the calculate_total_count method, which returns the returned value of the given block" do
      Massive::Step.calculates_total_count_with { 1234 }
      expect(Massive::Step.new.calculate_total_count).to eq(1234)
    end
  end

  describe "#enqueue" do
    before { step.save }

    let(:configured_job) { double(ActiveJob::ConfiguredJob) }

    it "enqueues a worker, passing step id as string, and setting the queue based on class queue" do
      expect(Massive::Worker).to receive(:set).with(queue: step.class.queue).and_return(configured_job)
      expect(configured_job).to receive(:perform_later).with(step.id.to_s)
      step.enqueue
    end

    it "marks the step as enqueued" do
      step.enqueue
      expect(step.reload.enqueued_at).to_not be_nil
    end

    it "sends a :enqueued notification" do
      expect(step).to receive(:notify).with(:enqueued)
      step.enqueue
    end
  end

  describe "#start!" do
    it "persists the total_count" do
      step.start!
      expect(step.reload.total_count).to be_present
    end

    it "sends a :start notification" do
      expect(step).to receive(:notify).with(:start)
      step.start!
    end

    context "when total_count is not defined" do
      it "updates it to zero" do
        step.start!
        expect(step.total_count).to be_zero
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
          expect(step.total_count).to eq(step.send(:calculate_total_count))
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
      expect(step).to receive(:start!) do
        expect(step).to receive(:process_step)
      end

      step.work
    end

    it "calls complete after processing step" do
      expect(step).to receive(:process_step) do
        expect(step).to receive(:complete)
      end

      step.work
    end
  end

  describe "jobs completion" do
    context "when it is not persisted" do
      it "does not reloads itself" do
        expect(step).to_not receive(:reload)
        step.completed_all_jobs?
      end
    end

    context "when it is persisted" do
      before { step.save }

      it "reloads itself, so that it can get the latest information" do
        expect(step).to receive(:reload).and_return(step)
        step.completed_all_jobs?
      end
    end

    context "when there are no jobs" do
      it { is_expected.to be_completed_all_jobs }
    end

    context "when there are jobs" do
      let!(:jobs) { step.jobs = 3.times.map { |i| Massive::Job.new } }

      before do
        jobs.each { |job| allow(job).to receive(:completed?).and_return(true) }
      end

      context "but there is at least one that is not completed" do
        before do
          jobs.each { |job| allow(job).to receive(:completed?).and_return(true) }

          allow(jobs.last).to receive(:completed?).and_return(false)
        end

        it { is_expected.to_not be_completed_all_jobs }
      end

      context "and all jobs are completed" do
        before do
          jobs.each { |job| allow(job).to receive(:completed?).and_return(true) }
        end

        it { is_expected.to be_completed_all_jobs }
      end
    end
  end

  describe "#complete" do
    context "when there is at least one job that is not completed" do
      before { allow(step).to receive(:completed_all_jobs?).and_return(false) }

      it "does not updates the finished_at" do
        step.complete
        expect(step.finished_at).to be_nil
      end

      it "does not updates the memory_consumption" do
        step.complete
        expect(step.memory_consumption).to be_zero
      end

      it "does not persists the step" do
        expect(step).to_not be_persisted
      end

      it "does not send a :complete notification" do
        expect(step).to_not receive(:notify).with(:complete)
        step.complete
      end

      context "when it is_expected.to not execute next after completion" do
        it "does not enqueues next step of process" do
          expect(process).to_not receive(:enqueue_next)
          step.complete
        end
      end

      context "when it is_expected.to execute next after completion" do
        before { step.execute_next = true }

        it "does not enqueues next step of process" do
          expect(process).to_not receive(:enqueue_next)
          step.complete
        end
      end
    end

    context "when all jobs are completed" do
      let(:lock_key) { step.send(:lock_key_for, :complete) }

      let(:redis) { Massive.redis }

      before { allow(step).to receive(:completed_all_jobs?).and_return(true) }

      context "but there is a complete lock for this step" do
        before do
          redis.set(lock_key, 1.minute.from_now)
        end

        it "does not updates the finished_at" do
          step.complete
          expect(step.finished_at).to be_nil
        end

        it "does not updates the memory_consumption" do
          step.complete
          expect(step.memory_consumption).to be_zero
        end

        it "does not persists the step" do
          expect(step).to_not be_persisted
        end

        it "does not send a :complete notification" do
          expect(step).to_not receive(:notify).with(:complete)
          step.complete
        end

        context "when it is_expected.to not execute next after completion" do
          it "does not enqueues next step of process" do
            expect(process).to_not receive(:enqueue_next)
            step.complete
          end
        end

        context "when it is_expected.to execute next after completion" do
          before { step.execute_next = true }

          it "does not enqueues next step of process" do
            expect(process).to_not receive(:enqueue_next)
            step.complete
          end
        end
      end

      context "but there is no complete lock for this step" do
        it "updates the finished_at with the current time, persisting it" do
          step.complete
          expect(step.reload.finished_at.to_i).to eq(now.to_i)
        end

        it "updates the memory_consumption, persisting it" do
          step.complete
          expect(step.reload.memory_consumption).to eq(current_memory_consumption)
        end

        it "sends a :complete notification" do
          expect(step).to receive(:notify).with(:complete)
          step.complete
        end

        context "when it is_expected.to not execute next after completion" do
          it "does not enqueues next step of process" do
            expect(process).to_not receive(:enqueue_next)
            step.complete
          end
        end

        context "when it is_expected.to execute next after completion" do
          before { step.execute_next = true }

          it "enqueues next step of process" do
            expect(process).to receive(:enqueue_next)
            step.complete
          end
        end
      end
    end
  end

  context "#process_step" do
    context "when total_count is not defined" do
      it "creates no jobs" do
        step.process_step
        expect(step.jobs).to be_empty
      end

      context "on custom step class" do
        subject(:step) { CustomStep.new }
        before { process.steps << step }

        it "creates jobs based on the calculated total_count, following the limit ratio" do
          step.process_step
          expect(step.jobs.size).to eq(1)
        end

        context "that has calculates total count, but evaluating to nil" do
          subject(:step) { CustomStepWithNilTotalCount.new }

          it "creates no jobs" do
            step.process_step
            expect(step.jobs).to be_empty
          end
        end
      end
    end

    context "when total_count is zero" do
      before { step.total_count = 0 }

      it "creates no jobs" do
        step.process_step
        expect(step.jobs).to be_empty
      end
    end

    context "when total_count is 2000" do
      before { step.total_count = 2000 }

      let(:limit) { 100 }

      it "creates 20 jobs, each processing 100 items" do
        step.process_step
        step.jobs.each_with_index do |job, index|
          expect(job.limit).to eq(limit)
          expect(job.offset).to eq(index * limit)
        end
      end

      it "creates jobs of the Massive::Job class" do
        step.process_step
        step.jobs.each do |job|
          expect(job).to be_an_instance_of(Massive::Job)
        end
      end

      context "on custom step class" do
        subject(:step) { CustomStep.new }
        before { process.steps << step }
        let(:limit) { 1000 }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            expect(job.limit).to eq(limit)
            expect(job.offset).to eq(index * limit)
          end
        end

        it "creates jobs of the redefined job_class" do
          step.process_step
          step.jobs.each do |job|
            expect(job).to be_an_instance_of(CustomJob)
          end
        end
      end

      context "on a inherited step, that didn't redefine any configuration" do
        subject(:step) { InheritedStep.new }
        before { process.steps << step }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            expect(job.limit).to eq(limit)
            expect(job.offset).to eq(index * limit)
          end
        end

        it "creates jobs of the Massive::Job" do
          step.process_step
          step.jobs.each do |job|
            expect(job).to be_an_instance_of(Massive::Job)
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
          expect(job.limit).to eq(limit)
          expect(job.offset).to eq(index * limit)
        end
      end

      context "on custom step class" do
        subject(:step) { CustomStep.new }
        before { process.steps << step }
        let(:limit) { 1500 }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            expect(job.limit).to eq(limit)
            expect(job.offset).to eq(index * limit)
          end
        end

        it "creates jobs of the redefined job_class" do
          step.process_step
          step.jobs.each do |job|
            expect(job).to be_an_instance_of(CustomJob)
          end
        end
      end

      context "on a inherited step, that didn't redefine any configuration" do
        subject(:step) { InheritedStep.new }
        before { process.steps << step }

        it "follows redefined limit_ratio, creating 2 jobs, each processing 1000 items" do
          step.process_step
          step.jobs.each_with_index do |job, index|
            expect(job.limit).to eq(limit)
            expect(job.offset).to eq(index * limit)
          end
        end

        it "creates jobs of the Massive::Job" do
          step.process_step
          step.jobs.each do |job|
            expect(job).to be_an_instance_of(Massive::Job)
          end
        end
      end
    end
  end

  describe "processed items and time" do
    context "when the step has no jobs" do
      its(:processed)            { is_expected.to be_zero }
      its(:processed_percentage) { is_expected.to be_zero }
      its(:processing_time)      { is_expected.to be_zero }
    end

    context "when the step has jobs with processed itens" do
      let!(:jobs) { step.jobs = 3.times.map { |i| Massive::Job.new(processed: 100 * i) } }
      let(:total_processed) { jobs.map(&:processed).sum }

      its(:processed) { is_expected.to eq(total_processed) }

      context "and the total count is zero" do
        its(:processed_percentage) { is_expected.to be_zero }
      end

      context "and the total count is greater than zero" do
        before { step.total_count = 1000 }

        its(:processed_percentage) { is_expected.to eq(total_processed.to_f / step.total_count) }
      end
    end

    context "when the step has jobs that have some elapsed time" do
      let!(:jobs) do
        step.jobs = 3.times.map do |i|
          Massive::Job.new.tap { |j| allow(j).to receive(:elapsed_time).and_return(100 * i) }
        end
      end

      let(:total_elapsed_time) { jobs.map(&:elapsed_time).sum }

      its(:processing_time) { is_expected.to eq(total_elapsed_time) }
    end
  end

  context "on a inherited step" do
    subject(:step) { InheritedStep.new }
    before { process.steps << step }

    it "properly sets the _type" do
      expect(step._type).to be_present
    end
  end

  describe "#active_model_serializer" do
    its(:active_model_serializer) { is_expected.to eq Massive::StepSerializer }

    context "when class inherits from Massive::Step and does not have a serializer" do
      class TestStep < Massive::Step
      end

      it "returns Massive::StepSerializer" do
        process = TestStep.new
        expect(process.active_model_serializer).to eq Massive::StepSerializer
      end
    end
  end
end
