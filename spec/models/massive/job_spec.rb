require "spec_helper"

describe Massive::Job do
  include_context "frozen time"
  include_context "stubbed memory_consumption"

  let(:process) { Massive::Process.new }
  let(:step) { process.steps.build }
  subject(:job) { step.jobs.build }

  before { allow(job).to receive(:process).and_return(process) }

  describe ".perform" do
    before do
      allow(Massive::Process).to receive(:find_job).with(process.id, step.id, job.id).and_return(job)
    end

    it "finds the job and calls work on it" do
      expect(job).to receive(:work)
      Massive::Job.perform(process.id, step.id, job.id)
    end
  end

  describe ".queue" do
    after { Massive::Job.queue_prefix(:massive_job) }

    it "should be massive_job" do
      expect(Massive::Job.queue).to eq(:massive_job)
    end

    it "should use queue_prefix" do
      Massive::Job.queue_prefix(:my_job_queue)
      expect(Massive::Job.queue).to eq(:my_job_queue)
    end

    context "when Massive.split_jobs is set to 100" do
      before { Massive.split_jobs = 100 }
      after  { Massive.split_jobs = false }

      it "should be massive_job_XXX where XXX is a random number" do
        values = 10000.times.inject({}) do |memo, index|
          match = Massive::Job.queue.to_s.match(/massive_job_(\d+)/)
          memo[match[1].to_i] ||= 0
          memo[match[1].to_i] += 1
          memo
        end

        (1..100).each do |key|
          expect(values.keys.sort).to include(key)
        end
      end

      it "should use the queue prefix" do
        Massive::Job.queue_prefix(:my_job_queue)
        expect(Massive::Job.queue.to_s).to start_with('my_job_queue')
      end

      context "when Job split_jobs is set to 10" do
        before { Massive::Job.split_jobs 200 }
        after  { Massive::Job.split_jobs false }

        it "should be massive_job_XXX where XXX is a random number between 1 and 10" do
          values = 10000.times.inject({}) do |memo, index|
            match = Massive::Job.queue.to_s.match(/massive_job_(\d+)/)
            memo[match[1].to_i] ||= 0
            memo[match[1].to_i] += 1
            memo
          end

          (1..200).each do |key|
            expect(values.keys.sort).to include(key)
          end
        end
      end
    end
  end

  describe "#enqueue" do
    it "enqueues itself, passing ids as strings" do
      expect(Resque).to receive(:enqueue).with(job.class, process.id.to_s, step.id.to_s, job.id.to_s)
      job.enqueue
    end

    context "when a subclass redefines calculate_total_count" do
      subject(:job) { CustomJob.new }
      before { step.jobs << job }

      it "enqueues itself, passing ids as strings" do
        expect(Resque).to receive(:enqueue).with(job.class, process.id.to_s, step.id.to_s, job.id.to_s)
        job.enqueue
      end
    end
  end

  describe "when creating" do
    it "enqueues the job" do
      expect(job).to receive(:enqueue)
      job.save
    end
  end

  describe "#start!" do
    it "zeroes the processed items, persisting it" do
      job.start!
      expect(job.reload.processed).to be_zero
    end
  end

  describe "#finish!" do
    it "updates the finished_at with the current time, persisting it" do
      job.finish!
      expect(job.reload.finished_at.to_i).to eq(now.to_i)
    end

    it "updates the memory_consumption, persisting it" do
      job.finish!
      expect(job.reload.memory_consumption).to eq(current_memory_consumption)
    end

    it "calls step#complete" do
      expect(step).to receive(:complete)
      job.finish!
    end
  end

  describe "#work" do
    it "starts the job, then runs through each item, and finally finishes the job" do
      expect(job).to receive(:start!) do
        expect(job).to receive(:each_item) do
          expect(job).to receive(:finish!)
        end
      end

      job.work
    end

    context "when it process one item" do
      include_context "job processing"

      it "increments the number of processed items by one" do
        job.work
        expect(job.reload.processed).to eq(1)
      end

      it "process the item" do
        expect(job).to receive(:process_each).with(item, 0).once
        job.work
      end
    end

    context "when it process multiple itens" do
      include_context "job processing"

      before do
        allow(job).to receive(:each_item)
          .and_yield(item, index)
          .and_yield(item, index + 1)
          .and_yield(item, index + 2)
      end

      it "increments the number of processed items by the number of items processed" do
        job.work
        expect(job.reload.processed).to eq(3)
      end

      it "process each one of the items" do
        expect(job).to receive(:process_each).with(item, 0).once
        expect(job).to receive(:process_each).with(item, 1).once
        expect(job).to receive(:process_each).with(item, 2).once
        job.work
      end

      it "sends a :progress notification" do
        expect(step).to receive(:notify).with(:progress).exactly(3).times
        expect(step).to receive(:notify).with(:complete).once
        job.work
      end
    end

    context "when it is cancelled" do
      before { allow(step).to receive(:notify) }

      context "before it is started" do
        before { allow(process).to receive(:cancelled?).and_return(true) }

        it "sends a cancelled notification" do
          expect(step).to receive(:notify).with(:cancelled)
          job.work
        end

        it "sets the step cancelled_at" do
          job.work
          expect(step.reload).to be_cancelled_at
        end

        it "sets the job cancelled_at" do
          job.work
          expect(job.reload).to be_cancelled_at
        end
      end

      context "while it is processing" do
        let(:item) { double(:item) }
        let(:index) { 0 }

        before do
          allow(job).to receive(:each_item)
            .and_yield(item, index)
            .and_yield(item, index + 1)
            .and_yield(item, index + 2)

          allow(job).to receive(:process_each)
          allow(process).to receive(:cancelled?).and_return(true)

          allow(Kernel).to receive(:sleep)
        end

        it "sends a cancelled notification" do
          expect(step).to receive(:notify).with(:cancelled)
          job.work
        end

        it "sets the step cancelled_at" do
          job.work
          expect(step.reload).to be_cancelled_at
        end

        it "sets the job cancelled_at" do
          job.work
          expect(job.reload).to be_cancelled_at
        end

        it "does not retry the processing" do
          expect(Kernel).to_not receive(:sleep)
          job.work
          expect(job.reload.retries).to be_zero
        end
      end
    end

    shared_examples_for "handles error" do
      it "re-raises the exception" do
        expect { job.work }.to raise_error(error)
      end

      it "sets the step as failed" do
        begin
          job.work
        rescue StandardError, SignalException
        end

        expect(step.reload).to be_failed
      end

      it "saves the last error" do
        begin
          job.work
        rescue StandardError, SignalException
        end

        expect(job.reload.last_error).to eq(error.message)
      end

      it "sends a :failed notification" do
        expect(step).to receive(:notify).with(:failed)

        begin
          job.work
        rescue StandardError, SignalException
        end
      end

      context "when it is configured to cancel when failed" do
        before { Massive::Job.cancel_when_failed true }
        after  { Massive::Job.cancel_when_failed false }

        it "cancels the process" do
          expect(process).to receive(:cancel)

          begin
            job.work
          rescue StandardError, SignalException
          end
        end
      end
    end

    context "when an error occurs" do
      let(:error) { StandardError.new('some-error') }

      context "while starting" do
        before { allow(job).to receive(:start!).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while running through each item" do
        before { allow(job).to receive(:each_item).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while processing each item" do
        include_context "job processing"

        before { allow(job).to receive(:process_each).and_raise(error) }

        it_should_behave_like "handles error"

        it "retries 10 times, with a 2 second interval" do
          expect(Kernel).to receive(:sleep).with(retry_interval).exactly(maximum_retries - 1).times
          expect(job).to receive(:process_each).exactly(maximum_retries).times.and_raise(error)
          expect { job.work }.to raise_error(error)
          expect(job.reload.retries).to eq(maximum_retries)
        end

        context "when a subclass redefines the retry interval and maximum retries" do
          subject(:job) { CustomJob.new }
          before { step.jobs << job }

          it "retries 20 times, with a 5 second interval" do
            expect(Kernel).to receive(:sleep).with(retry_interval).exactly(maximum_retries - 1).times
            expect(job).to receive(:process_each).exactly(maximum_retries).times.and_raise(error)
            expect { job.work }.to raise_error(error)
            expect(job.reload.retries).to eq(maximum_retries)
          end
        end
      end

      context "while finishing" do
        before { allow(job).to receive(:finish!).and_raise(error) }

        it_should_behave_like "handles error"
      end
    end

    context "when a system signal is sent" do
      let(:error) { SignalException.new('TERM') }

      context "while starting" do
        before { allow(job).to receive(:start!).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while running through each item" do
        before { allow(job).to receive(:each_item).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while processing each item" do
        include_context "job processing"

        before { allow(job).to receive(:process_each).and_raise(error) }

        it_should_behave_like "handles error"

        it "does not retry the processing, raising error immediately" do
          expect(Kernel).to_not receive(:sleep)
          expect(job).to receive(:process_each).once.and_raise(error)
          expect { job.work }.to raise_error(error)
          expect(job.reload.retries).to be_zero
        end
      end

      context "while finishing" do
        before { allow(job).to receive(:finish!).and_raise(error) }

        it_should_behave_like "handles error"
      end
    end
  end

  context "on a subclass" do
    subject(:job) { CustomJob.new }
    before { step.jobs << job }

    it "properly sets the _type" do
      expect(job._type).to be_present
    end
  end
end
