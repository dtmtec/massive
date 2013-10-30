shared_context "stubbed memory_consumption" do
  let(:current_memory_consumption) { 123456 }

  before { subject.stub(:current_memory_consumption).and_return(current_memory_consumption) }
end

shared_context "frozen time" do
  let!(:now) do
    Time.now.tap do |now|
      Time.stub(:now).and_return(now)
    end
  end
end

shared_context "job processing" do
  let(:item) { double(:item) }
  let(:index) { 0 }
  let(:retry_interval)  { job.class.retry_interval }
  let(:maximum_retries) { job.class.maximum_retries }

  before do
    Kernel.stub(:sleep)
    job.stub(:each_item).and_yield(item, index)
  end
end
