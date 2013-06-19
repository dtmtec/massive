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
    it "should be massive_job" do
      Massive::Job.queue.should eq(:massive_job)
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
    end

    shared_examples_for "handles error" do
      context "while starting" do
        before { job.stub(:start!).and_raise(error) }

        it "sets the job as failed, then re-raises the exception" do
          expect { job.work }.to raise_error(error)
          job.reload.should be_failed
        end

        it "sets the step as failed" do
          expect { job.work }.to raise_error(error)
          step.reload.should be_failed
        end

        it "saves the last error" do
          expect { job.work }.to raise_error(error)
          job.reload.last_error.should eq(error.message)
        end
      end

      context "while running throught each item" do
        before { job.stub(:each_item).and_raise(error) }

        it "sets the job as failed, then re-raises the exception" do
          expect { job.work }.to raise_error(error)
          job.reload.should be_failed
        end

        it "saves the last error" do
          expect { job.work }.to raise_error(error)
          job.reload.last_error.should eq(error.message)
        end
      end

      context "while processing each item" do
        include_context "job processing"

        before { job.stub(:process_each).and_raise(error) }

        it "sets the job as failed, then re-raises the exception" do
          expect { job.work }.to raise_error(error)
          job.reload.should be_failed
        end

        it "saves the last error" do
          expect { job.work }.to raise_error(error)
          job.reload.last_error.should eq(error.message)
        end
      end

      context "while finishing" do
        before { job.stub(:finish!).and_raise(error) }

        it "sets the job as failed, then re-raises the exception" do
          expect { job.work }.to raise_error(error)
          job.reload.should be_failed
        end

        it "saves the last error" do
          expect { job.work }.to raise_error(error)
          job.reload.last_error.should eq(error.message)
        end
      end
    end

    context "when an error occurs" do
      let(:error) { StandardError.new('some-error') }

      it_should_behave_like "handles error"

      context "while processing each item" do
        include_context "job processing"

        before { job.stub(:process_each).and_raise(error) }

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
    end

    context "when a system signal is sent" do
      let(:error) { SignalException.new('TERM') }

      it_should_behave_like "handles error"

      context "while processing each item" do
        include_context "job processing"

        before { job.stub(:process_each).and_raise(error) }

        it "does not retry the processing, raising error immediately" do
          Kernel.should_not_receive(:sleep)
          job.should_receive(:process_each).once.and_raise(error)
          expect { job.work }.to raise_error(error)
          job.reload.retries.should be_zero
        end
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
