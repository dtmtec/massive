require "spec_helper"

describe Massive do
  before do
    Massive.redis = nil
  end

  describe ".redis" do
    it "returns a namespaced redis instance" do
      expect(Massive.redis).to be_a(Redis::Namespace)
    end

    it "uses :massive as namespace" do
      expect(Massive.redis.namespace).to eq(:massive)
    end

    context "when REDIS_NAMESPACE variable is set" do
      before { ENV['REDIS_NAMESPACE'] = 'some_name' }
      after  { ENV['REDIS_NAMESPACE'] = '' }

      it "uses it as namespace" do
        expect(Massive.redis.namespace).to eq('some_name')
      end
    end
  end

  describe ".redis=(client)" do
    let(:client) { Redis.new }

    it "sets a redis client" do
      Massive.redis = client
      expect(Massive.redis).to eq(client)
    end
  end
end
