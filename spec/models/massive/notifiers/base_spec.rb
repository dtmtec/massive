require 'spec_helper'

describe Massive::Notifiers::Base do
  let(:id) { 'some-id' }
  subject(:notifier) { Massive::Notifiers::Base.new(id) }

  it_should_behave_like Massive::Locking

  describe "#notify(message, data)" do
    let(:redis) { Massive.redis }

    let(:message) { :some_message }
    let(:data)    { { some: 'data' } }

    context "when a notification for this message is not locked" do
      it "sends a notification" do
        notifier.notify(message, data)
        expect(notifier.last[:message]).to eq(message)
        expect(notifier.last[:data]).to eq(data)
      end

      context "when a block is given" do
        it "sends a notification with the data being the return from the block" do
          notifier.notify(message) { data }
          expect(notifier.last[:message]).to eq(message)
          expect(notifier.last[:data]).to eq(data)
        end
      end
    end

    context "when a notification for this message is locked" do
      let(:lock_key) { subject.send(:lock_key_for, message) }
      before { redis.set(lock_key, 60) }

      it "does not send a notification" do
        notifier.notify(message, data)
        expect(notifier.last[:message]).to be_nil
        expect(notifier.last[:data]).to be_nil
      end

      context "when a block is given" do
        it "does not execute the block" do
          notifier.notify(message) { fail('should not execute this block') }
        end
      end
    end
  end
end
