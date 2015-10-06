require "spec_helper"

describe Massive::Process do
  subject(:process) { Massive::Process.create }

  describe "#enqueue_next" do
    context "when there is a next step" do
      let(:step) { process.steps.create }

      before do
        allow(process).to receive(:next_step).and_return(step)
      end

      it "enqueues the step" do
        expect(step).to receive(:enqueue)
        process.enqueue_next
      end
    end

    context "when there is no next step" do
      before do
        allow(process).to receive(:next_step).and_return(nil)
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
      allow(process).to receive(:steps).and_return(steps)
      allow(steps).to receive(:not_completed).and_return(steps)
      allow(steps).to receive(:not_started).and_return(steps)
      allow(steps).to receive(:not_enqueued).and_return(steps)
      allow(steps).to receive(:first).and_return(step)
    end

    it "returns the first step that is not completed, not started and not enqueued" do
      expect(process.next_step).to eq(step)
    end
  end

  describe "#processed_percentage" do
    let(:step_1)  { process.steps.create(weight: 9) }
    let(:step_2)  { process.steps.create            }

    context "when the process have not started" do
      before do
        allow(step_1).to receive(:processed_percentage).and_return(0)
        allow(step_2).to receive(:processed_percentage).and_return(0)
      end

      its(:processed_percentage) { is_expected.to eq 0 }
    end

    context "when the process have finished" do
      before do
        allow(step_1).to receive(:processed_percentage).and_return(1)
        allow(step_2).to receive(:processed_percentage).and_return(1)
      end

      its(:processed_percentage) { is_expected.to eq 1 }
    end

    context "when the file export step is finished" do
      before { allow(step_1).to receive(:processed_percentage).and_return(1) }

      context "and the file upload step is not finished" do
        before { allow(step_2).to receive(:processed_percentage).and_return(0) }

        its(:processed_percentage) { is_expected.to eq 0.9 }
      end
    end

    context "when the file export step is finished" do
      before { allow(step_1).to receive(:processed_percentage).and_return(1) }

      context "and the file upload step is finished" do
        before { allow(step_2).to receive(:processed_percentage).and_return(1) }

        its(:processed_percentage) { is_expected.to eq 1 }
      end
    end

    context "when the file export step is finished" do
      before { allow(step_1).to receive(:processed_percentage).and_return(1) }

      context "and the file upload step is half way to be finished" do
        before { allow(step_2).to receive(:processed_percentage).and_return(0.5) }

        its(:processed_percentage) { is_expected.to eq 0.95 }
      end
    end

    context "when the total weight of the steps is zero" do
      let(:step_1)  { process.steps.create(weight: 0) }
      let(:step_2)  { process.steps.create(weight: 0) }

      its(:processed_percentage) { is_expected.to eq 0 }
    end
  end

  describe "#completed?" do
    before { process.save }

    let!(:step_1)  { process.steps.create }
    let!(:step_2)  { process.steps.create }

    context "when the steps are incompleted steps" do
      its(:completed?) { is_expected.to be_falsy }
    end

    context "when there are no incompleted steps" do
      before do
        step_1.update_attributes(finished_at: Time.now, failed_at: nil)
        step_2.update_attributes(finished_at: Time.now, failed_at: nil)
      end

      its(:completed?) { is_expected.to be_truthy }
    end
  end

  describe "#failed?" do
    let!(:step_1) { process.steps.create }
    let!(:step_2) { process.steps.create }

    before { process.save }

    context "when the steps not failed" do
      its(:failed?) { is_expected.to be_falsy }
    end

    context "when any step failed" do
      before { step_2.update_attributes(failed_at: Time.now) }

      its(:failed?) { is_expected.to be_truthy }
    end
  end

  describe "#cancel" do
    let!(:now) do
      Time.now.tap do |now|
        allow(Time).to receive(:now).and_return(now)
      end
    end

    it "sets cancelled_at to the current time, persisting it" do
      process.cancel
      expect(process.reload.cancelled_at.to_i).to eq(now.to_i)
    end

    it "sets a cancelled key in redis with the process id" do
      process.cancel
      expect(Massive.redis.exists("#{process.class.name.underscore}:#{process.id}:cancelled")).to be_truthy
    end
  end

  describe "#canceled?" do
    context "when it has a cancelled_at" do
      before { process.cancelled_at = Time.now }

      it { is_expected.to be_cancelled }
    end

    context "when it doesn't have a cancelled_at" do
      it { is_expected.to_not be_cancelled }

      context "but there is a cancelled key for this process in redis" do
        before { Massive.redis.set("#{process.class.name.underscore}:#{process.id}:cancelled", true) }

        it { is_expected.to be_cancelled }
      end
    end
  end

  describe "#active_model_serializer" do
    its(:active_model_serializer) { is_expected.to eq Massive::ProcessSerializer }

    context "when class inherits from Massive::Process and does not have a serializer" do
      class TestProcess < Massive::Process
      end

      it "returns Massive::ProcessSerializer" do
        process = TestProcess.new
        expect(process.active_model_serializer).to eq Massive::ProcessSerializer
      end
    end
  end
end
