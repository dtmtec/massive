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
end
