require "spec_helper"

describe Massive::Job do
  include_context "frozen time"
  include_context "stubbed memory_consumption"

  let(:process) { Massive::Process.new }
  let(:step) { process.steps.build }
  subject(:job) { step.jobs.build }

  describe ".perform" do
    before do
      Massive::Process.stub(:find_job).with(process.id, step.id, job.id).and_return(job)
    end

    it "finds the job and calls work on it" do
      job.should_receive(:work)
      Massive::Job.perform(process.id, step.id, job.id)
    end
  end

  describe ".queue" do
    after { Massive::Job.queue_prefix(:massive_job) }

    it "should be massive_job" do
      Massive::Job.queue.should eq(:massive_job)
    end

    it "should use queue_prefix" do
      Massive::Job.queue_prefix(:my_job_queue)
      Massive::Job.queue.should eq(:my_job_queue)
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
      Resque.should_receive(:enqueue).with(job.class, process.id.to_s, step.id.to_s, job.id.to_s)
      job.enqueue
    end

    context "when a subclass redefines calculate_total_count" do
      subject(:job) { CustomJob.new }
      before { step.jobs << job }

      it "enqueues itself, passing ids as strings" do
        Resque.should_receive(:enqueue).with(job.class, process.id.to_s, step.id.to_s, job.id.to_s)
        job.enqueue
      end
    end
  end

  describe "when creating" do
    it "enqueues the job" do
      job.should_receive(:enqueue)
      job.save
    end
  end

  describe "#start!" do
    it "zeroes the processed items, persisting it" do
      job.start!
      job.reload.processed.should be_zero
    end
  end

  describe "#finish!" do
    it "updates the finished_at with the current time, persisting it" do
      job.finish!
      job.reload.finished_at.to_i.should eq(now.to_i)
    end

    it "updates the memory_consumption, persisting it" do
      job.finish!
      job.reload.memory_consumption.should eq(current_memory_consumption)
    end

    it "calls step#complete" do
      step.should_receive(:complete)
      job.finish!
    end
  end

  describe "#work" do
    it "starts the job, then runs through each item, and finally finishes the job" do
      job.should_receive(:start!) do
        job.should_receive(:each_item) do
          job.should_receive(:finish!)
        end
      end

      job.work
    end

    context "when it process one item" do
      include_context "job processing"

      it "increments the number of processed items by one" do
        job.work
        job.reload.processed.should eq(1)
      end

      it "process the item" do
        job.should_receive(:process_each).with(item, 0).once
        job.work
      end
    end

    context "when it process multiple itens" do
      include_context "job processing"

      before do
        job.stub(:each_item).and_yield(item, index)
                            .and_yield(item, index + 1)
                            .and_yield(item, index + 2)
      end

      it "increments the number of processed items by the number of items processed" do
        job.work
        job.reload.processed.should eq(3)
      end

      it "process each one of the items" do
        job.should_receive(:process_each).with(item, 0).once
        job.should_receive(:process_each).with(item, 1).once
        job.should_receive(:process_each).with(item, 2).once
        job.work
      end

      it "sends a :progress notification" do
        step.stub(:notify)
        step.should_receive(:notify).with(:progress)
        job.work
      end
    end

    context "when it is cancelled" do
      before { step.stub(:notify) }

      context "before it is started" do
        before { process.stub(:cancelled?).and_return(true) }

        it "sends a cancelled notification" do
          step.should_receive(:notify).with(:cancelled)
          job.work
        end

        it "sets the step cancelled_at" do
          job.work
          step.reload.should be_cancelled_at
        end

        it "sets the job cancelled_at" do
          job.work
          job.reload.should be_cancelled_at
        end
      end

      context "while it is processing" do
        let(:item) { double(:item) }
        let(:index) { 0 }

        before do
          job.stub(:each_item).and_yield(item, index)
                              .and_yield(item, index + 1)
                              .and_yield(item, index + 2)

          job.stub(:process_each) do
            process.stub(:cancelled?).and_return(true)
          end

          Kernel.stub(:sleep)
        end

        it "sends a cancelled notification" do
          step.should_receive(:notify).with(:cancelled)
          job.work
        end

        it "sets the step cancelled_at" do
          job.work
          step.reload.should be_cancelled_at
        end

        it "sets the job cancelled_at" do
          job.work
          job.reload.should be_cancelled_at
        end

        it "does not retry the processing" do
          Kernel.should_not_receive(:sleep)
          job.work
          job.reload.retries.should be_zero
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

        step.reload.should be_failed
      end

      it "saves the last error" do
        begin
          job.work
        rescue StandardError, SignalException
        end

        job.reload.last_error.should eq(error.message)
      end

      it "sends a :failed notification" do
        step.stub(:notify)
        step.should_receive(:notify).with(:failed)

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
        before { job.stub(:start!).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while running through each item" do
        before { job.stub(:each_item).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while processing each item" do
        include_context "job processing"

        before { job.stub(:process_each).and_raise(error) }

        it_should_behave_like "handles error"

        it "retries 10 times, with a 2 second interval" do
          Kernel.should_receive(:sleep).with(retry_interval).exactly(maximum_retries - 1).times
          job.should_receive(:process_each).exactly(maximum_retries).times.and_raise(error)
          expect { job.work }.to raise_error(error)
          job.reload.retries.should eq(maximum_retries)
        end

        context "when a subclass redefines the retry interval and maximum retries" do
          subject(:job) { CustomJob.new }
          before { step.jobs << job }

          it "retries 20 times, with a 5 second interval" do
            Kernel.should_receive(:sleep).with(retry_interval).exactly(maximum_retries - 1).times
            job.should_receive(:process_each).exactly(maximum_retries).times.and_raise(error)
            expect { job.work }.to raise_error(error)
            job.reload.retries.should eq(maximum_retries)
          end
        end
      end

      context "while finishing" do
        before { job.stub(:finish!).and_raise(error) }

        it_should_behave_like "handles error"
      end
    end

    context "when a system signal is sent" do
      let(:error) { SignalException.new('TERM') }

      context "while starting" do
        before { job.stub(:start!).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while running through each item" do
        before { job.stub(:each_item).and_raise(error) }

        it_should_behave_like "handles error"
      end

      context "while processing each item" do
        include_context "job processing"

        before { job.stub(:process_each).and_raise(error) }

        it_should_behave_like "handles error"

        it "does not retry the processing, raising error immediately" do
          Kernel.should_not_receive(:sleep)
          job.should_receive(:process_each).once.and_raise(error)
          expect { job.work }.to raise_error(error)
          job.reload.retries.should be_zero
        end
      end

      context "while finishing" do
        before { job.stub(:finish!).and_raise(error) }

        it_should_behave_like "handles error"
      end
    end
  end

  context "on a subclass" do
    subject(:job) { CustomJob.new }
    before { step.jobs << job }

    it "properly sets the _type" do
      job._type.should be_present
    end
  end
end
