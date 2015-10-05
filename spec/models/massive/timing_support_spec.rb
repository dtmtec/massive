shared_examples_for Massive::TimingSupport do
  include_context "frozen time"

  context "when it has not been started" do
    its(:elapsed_time) { is_expected.to be_zero }
  end

  context "when it has been started" do
    let(:started_at) { 1.minute.ago }
    before { subject.started_at = started_at }

    context "1 minute ago" do
      context "and it has not been finished yet" do
        its(:elapsed_time) { is_expected.to eq(now - started_at) }

        it { is_expected.to_not be_completed }
      end

      context "and it has been finished 10 seconds ago" do
        let(:finished_at) { 10.seconds.ago }
        before { subject.finished_at = finished_at }

        its(:elapsed_time) { is_expected.to eq(finished_at - started_at) }

        it { is_expected.to be_completed }
      end
    end

    context "2 hours ago" do
      let(:started_at) { 2.hours.ago }

      context "and it has not been finished yet" do
        its(:elapsed_time) { is_expected.to eq(now - started_at) }

        it { is_expected.to_not be_completed }
      end

      context "and has been finished 30 minutes ago" do
        let(:finished_at) { 30.minutes.ago }
        before { subject.finished_at = finished_at }

        its(:elapsed_time) { is_expected.to eq(finished_at - started_at) }
        it { is_expected.to be_completed }
      end
    end
  end
end

describe Massive::Step do
  it_should_behave_like Massive::TimingSupport
end

describe Massive::Job do
  it_should_behave_like Massive::TimingSupport
end
