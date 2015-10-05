require "spec_helper"

shared_examples_for Massive::Locking do
  let(:redis) { Resque.redis }
  let(:key)   { :some_key }

  context "when there is a lock for the given key" do
    let(:lock_key) { subject.send(:lock_key_for, key) }
    before { redis.set(lock_key, 60) }

    it { is_expected.to be_locked(key) }

    it "does not sets the an expiration for the key" do
      expect(redis).to_not receive(:pexpire)
      subject.locked?(key)
    end
  end

  context "when there is no lock for the given key" do
    let(:lock_key) { subject.send(:lock_key_for, key) }

    it { is_expected.to_not be_locked(key) }

    context "and an expiration is not given for the locked key" do
      it "sets the expiration to 60 seconds, specifying in miliseconds" do
        expect(redis).to receive(:pexpire).with(lock_key, 60 * 1000)
        subject.locked?(key)
      end
    end

    context "and an expiration is given for the locked key" do
      it "sets the expiration to this value" do
        expect(redis).to receive(:pexpire).with(lock_key, 10)
        subject.locked?(key, 10)
      end
    end

    context "when pexpire command is not supported" do
      let(:error) { Redis::CommandError.new('not supported') }
      before { allow(redis).to receive(:pexpire).and_raise(error) }

      it "should set expiration using expire command, dividing expiration per 1000 and rounding" do
        expect(redis).to receive(:expire).with(lock_key, (1500/1000).to_i)
        subject.locked?(key, 1500)
      end
    end
  end
end

describe Massive::Step do
  it_should_behave_like Massive::Locking
end
