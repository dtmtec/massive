shared_examples_for Massive::Locking do
  let(:redis) { Resque.redis }
  let(:key)   { :some_key }

  before { redis.flushdb }
  after  { redis.flushdb }

  context "when there is a lock for the given key" do
    let(:lock_key) { subject.send(:lock_key_for, key) }
    before { redis.set(lock_key, 1.minute) }

    it { should be_locked(key) }
  end

  context "when there is no lock for the given key" do
    it { should_not be_locked(key) }
  end
end

describe Massive::Step do
  it_should_behave_like Massive::Locking
end
