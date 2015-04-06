require "spec_helper"

describe Massive::Process do
  subject(:process) { Massive::Process.create }

  describe "#enqueue_next" do
    context "when there is a next steps" do
      let(:step) { process.steps.create }

      before do
        process.stub(:next_step).and_return(step)
      end

      it "enqueues the step" do
        step.should_receive(:enqueue)
        process.enqueue_next
      end
    end

    context "when there is no next step" do
      before do
        process.stub(:next_step).and_return(nil)
      end

      it "does not raise error" do
        expect {
          process.enqueue_next
        }.to_not raise_error
      end
    end
  end

  describe "#next_step" do
    let!(:step) { process.steps.create }

    before do
      steps = double('Array')
      process.stub(:steps).and_return(steps)
      steps.stub(:not_completed).and_return(steps)
      steps.stub(:not_started).and_return(steps)
      steps.stub(:first).and_return(step)
    end

    context "when the step is enqueued" do
      before { step.stub(:enqueued?).and_return(true) }

      its(:next_step) { should be_nil }
    end

    context "when the step is not enqueued" do
      before { step.stub(:enqueued?).and_return(false) }

      its(:next_step) { should eq step }
    end
  end

  describe ".find_step" do
    let!(:step) { process.steps.create }

    it "returns the step with id within the process" do
      Massive::Process.find_step(process.id, step.id).should eq(step)
    end
  end

  describe ".find_job" do
    let!(:step) { process.steps.create }
    let!(:job)  { step.jobs.create }

    it "returns the job with id within the step of the process" do
      Massive::Process.find_job(process.id, step.id, job.id).should eq(job)
    end
  end

  describe "#processed_percentage" do
    let(:step_1)  { process.steps.create(weight: 9) }
    let(:step_2)  { process.steps.create            }

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
      let(:step_1)  { process.steps.create(weight: 0) }
      let(:step_2)  { process.steps.create(weight: 0) }

      its(:processed_percentage) { should eq 0 }
    end
  end

  describe "#completed?" do
    before { process.save }

    let!(:step_1)  { process.steps.create }
    let!(:step_2)  { process.steps.create }

    context "when the steps are incompleted steps" do
      its(:completed?) { should be_false }
    end

    context "when there are no incompleted steps" do
      before do
        step_1.update_attributes(finished_at: Time.now, failed_at: nil)
        step_2.update_attributes(finished_at: Time.now, failed_at: nil)
      end

      its(:completed?) { should be_true }
    end
  end

  describe "#failed?" do
    let!(:step_1) { process.steps.create }
    let!(:step_2) { process.steps.create }

    before { process.save }

    context "when the steps not failed" do
      its(:failed?) { should be_false }
    end

    context "when any step failed" do
      before { step_2.update_attributes(failed_at: Time.now) }

      its(:failed?) { should be_true }
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
