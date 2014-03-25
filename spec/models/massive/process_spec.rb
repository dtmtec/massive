require "spec_helper"

describe Massive::Process do
  subject(:process) { Massive::Process.new }

  describe "#enqueue_next" do
    context "when there are steps" do
      let!(:first_step) { process.steps.build }
      let!(:second_step) { process.steps.build }
      let!(:third_step) { process.steps.build }

      context "and none of them are completed" do
        it "enqueues the first step" do
          first_step.should_receive(:enqueue)
          process.enqueue_next
        end

        it "does not enqueue the other steps" do
          second_step.should_not_receive(:enqueue)
          third_step.should_not_receive(:enqueue)
          process.enqueue_next
        end
      end

      context "and the first one is completed, but the second one is not" do
        before { first_step.finished_at = Time.now }

        it "does not enqueue the first step" do
          first_step.should_not_receive(:enqueue)
          process.enqueue_next
        end

        it "enqueues the second step" do
          second_step.should_receive(:enqueue)
          process.enqueue_next
        end

        it "does not enqueue the third step" do
          third_step.should_not_receive(:enqueue)
          process.enqueue_next
        end
      end

      context "and the first one is enqueued" do
        before { first_step.stub(:enqueued?).and_return(true) }

        it "does not enqueue the next step" do
          second_step.should_not_receive(:enqueue)
          process.enqueue_next
        end
      end

      context "but all of them are completed" do
        before do
          process.steps.each do |step|
            step.finished_at = Time.now
          end
        end

        it "does not enqueue any of the steps" do
          process.steps.each do |step|
            step.should_not_receive(:enqueue)
          end

          process.enqueue_next
        end
      end
    end
  end

  describe "#next_step" do
    let!(:step) { process.steps.build }

    context "when the step is enqueued" do
      before { step.stub(:enqueued?).and_return(true) }

      its(:next_step) { should be_nil }
    end

    context "when the step is not enqueued" do
      its(:next_step) { should eq step }
    end
  end

  describe ".find_step" do
    let!(:step) { process.steps.build }

    before { process.save }

    it "returns the step with id within the process" do
      Massive::Process.find_step(process.id, step.id).should eq(step)
    end
  end

  describe ".find_job" do
    let!(:step) { process.steps.build }
    let!(:job)  { step.jobs.build }

    before { process.save }

    it "returns the job with id within the step of the process" do
      Massive::Process.find_job(process.id, step.id, job.id).should eq(job)
    end
  end

  describe "#processed_percentage" do
    let(:step_1)  { process.steps.build(weight: 9) }
    let(:step_2)  { process.steps.build            }

    context "when the process have not started" do
      before do
        step_1.stub(:processed_percentage).and_return(0)
        step_2.stub(:processed_percentage).and_return(0)
      end

      its(:processed_percentage) { should eq 0 }
    end

    context "when the process have finished" do
      before do
        step_1.stub(:processed_percentage).and_return(1)
        step_2.stub(:processed_percentage).and_return(1)
      end

      its(:processed_percentage) { should eq 1 }
    end

    context "when the file export step is finished" do
      before { step_1.stub(:processed_percentage).and_return(1) }

      context "and the file upload step is not finished" do
        before { step_2.stub(:processed_percentage).and_return(0) }

        its(:processed_percentage) { should eq 0.9 }
      end
    end

    context "when the file export step is finished" do
      before { step_1.stub(:processed_percentage).and_return(1) }

      context "and the file upload step is finished" do
        before { step_2.stub(:processed_percentage).and_return(1) }

        its(:processed_percentage) { should eq 1 }
      end
    end

    context "when the file export step is finished" do
      before { step_1.stub(:processed_percentage).and_return(1) }

      context "and the file upload step is half way to be finished" do
        before { step_2.stub(:processed_percentage).and_return(0.5) }

        its(:processed_percentage) { should eq 0.95 }
      end
    end

    context "when the total weight of the steps is zero" do
      let(:step_1)  { process.steps.build(weight: 0) }
      let(:step_2)  { process.steps.build(weight: 0) }

      its(:processed_percentage) { should eq 0 }
    end
  end

  describe "#completed?" do
    let!(:step_1)  { process.steps.build }
    let!(:step_2)  { process.steps.build }

    before { process.save }

    context "when the steps are incompleted steps" do
      its(:completed?) { should be_false }
    end

    context "when therere are no incompleted steps" do
      before do
        step_1.update_attributes(finished_at: Time.now, failed_at: nil)
        step_2.update_attributes(finished_at: Time.now, failed_at: nil)
      end

      its(:completed?) { should be_true }
    end
  end

  describe "#cancel" do
    let!(:now) do
      Time.now.tap do |now|
        Time.stub(:now).and_return(now)
      end
    end

    it "sets cancelled_at to the current time, persisting it" do
      process.cancel
      process.reload.cancelled_at.to_i.should eq(now.to_i)
    end

    it "sets a cancelled key in redis with the process id" do
      process.cancel
      Massive.redis.exists("#{process.class.name.underscore}:#{process.id}:cancelled").should be_true
    end
  end

  describe "#canceled?" do
    context "when it has a cancelled_at" do
      before { process.cancelled_at = Time.now }

      it { should be_cancelled }
    end

    context "when it doesn't have a cancelled_at" do
      it { should_not be_cancelled }

      context "but there is a cancelled key for this process in redis" do
        before { Massive.redis.set("#{process.class.name.underscore}:#{process.id}:cancelled", true) }

        it { should be_cancelled }
      end
    end
  end

  describe "#active_model_serializer" do
    its(:active_model_serializer) { should eq Massive::ProcessSerializer }

    context "when class inherits from Massive::Process and does not have a serializer" do
      class TestProcess < Massive::Process
      end

      it "returns Massive::ProcessSerializer" do
        process = TestProcess.new
        process.active_model_serializer.should eq Massive::ProcessSerializer
      end
    end
  end
end
