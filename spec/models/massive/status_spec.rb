shared_examples_for Massive::Status do
  include_context "frozen time"

  context "when it has not been started" do
    it { should_not be_started }
    it { should_not be_completed }
    it { should_not be_failed }
  end

  context "when it has been started" do
    let(:started_at) { 1.minute.ago }
    before { model.started_at = started_at }

    it { should be_started }
    it { should_not be_completed }
    it { should_not be_failed }

    context "1 minute ago" do
      context "and it has not been finished yet" do
        it { should be_started }
        it { should_not be_completed }
        it { should_not be_failed }
      end

      context "and it has been finished 10 seconds ago" do
        let(:finished_at) { 10.seconds.ago }
        before { model.finished_at = finished_at }

        it { should be_started }
        it { should be_completed }
        it { should_not be_failed }

        context "and it has failed" do
          let(:failed_at) { 1.minute.ago }
          before { model.failed_at = failed_at }

          it { should_not be_started }
          it { should_not be_completed }
          it { should be_failed }
        end
      end
    end

    context "and it has failed" do
      let(:failed_at) { 1.minute.ago }
      before { model.failed_at = failed_at }

      it { should_not be_started }
      it { should_not be_completed }
      it { should be_failed }
    end
  end

  describe "#start!" do
    it "updates the started_at with the current time, persisting it" do
      model.start!
      model.reload.started_at.to_i.should eq(now.to_i)
    end

    it "clears the finished_at, persisting it" do
      model.update_attributes(finished_at: now)
      model.start!
      model.reload.finished_at.should be_nil
    end

    it "clears the failed_at, persisting it" do
      model.update_attributes(failed_at: now)
      model.start!
      model.reload.failed_at.should be_nil
    end

    it "zeroes the number of retries, persisting it" do
      model.start!
      model.reload.retries.should be_zero
    end
  end

  describe "#enqueued?" do
    context "when model is enqueued" do
      before do
        model.stub(:reload).and_return(model)
        model.enqueue
      end

      its(:enqueued?) { should be_true }
    end

    context "when model is not enqueued" do
      its(:enqueued?) { should be_false }
    end
  end
end

describe Massive::Step do
  let(:process) { Massive::Process.new }
  subject(:model) { process.steps.build }

  it_should_behave_like Massive::Status
end

describe Massive::Job do
  let(:process) { Massive::Process.new }
  let(:step) { process.steps.build }
  subject(:model) { step.jobs.build }

  it_should_behave_like Massive::Status
end
