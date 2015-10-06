require "spec_helper"

describe Massive::Worker do
  let(:arguments)  { [] }
  subject(:worker) { described_class.new(*arguments) }

  describe "#worker(step_id, job_id)" do
    let(:step) { Massive::Step.create }
    let(:job)  { step.jobs.create }

    context "when passing only a step id" do
      it "returns the step for the id" do
        expect(worker.worker(step.id.to_s)).to eq(step)
      end
    end

    context "when passing both step and job ids" do
      it "returns the job for the id, searching from the step with the given step id" do
        expect(worker.worker(step.id.to_s, job.id.to_s)).to eq(job)
      end
    end
  end

  describe "#perform(*arguments)" do
    let(:step) { Massive::Step.create }
    let(:job)  { step.jobs.create }

    before do
      allow(worker).to receive(:worker).with(step.id.to_s).and_return(step)
      allow(worker).to receive(:worker).with(step.id.to_s, job.id.to_s).and_return(job)
    end

    context "when passing only step_id" do
      it "calls #work on the step" do
        expect(step).to receive(:work)
        worker.perform(step.id.to_s)
      end
    end

    context "when passing both step_id and job_id" do
      it "calls #work on the job" do
        expect(job).to receive(:work)
        worker.perform(step.id.to_s, job.id.to_s)
      end
    end
  end
end
