require 'spec_helper'

describe Massive::Notifiers::Pusher do
  let(:id) { 'pusher_notifier' }

  let(:client)       { double('Pusher') }
  subject(:notifier) { Massive::Notifiers::Pusher.new(id, client: client) }

  it_should_behave_like Massive::Locking

  it { should be_a(Massive::Notifiers::Base) }

  describe "#notify(message, data)" do
    let(:redis) { Resque.redis }

    let(:message) { :some_message }
    let(:data)    { { some: 'data' } }

    context "when a notification for this message is not locked" do
      it "sends a notification" do
        client.should_receive(:trigger).with(id, message, data)
        notifier.notify(message, data)
      end

      context "when a block is given" do
        it "sends a notification with the data being the return from the block" do
          client.should_receive(:trigger).with(id, message, data)
          notifier.notify(message) { data }
        end
      end
    end

    context "when a notification for this message is locked" do
      let(:lock_key) { subject.send(:lock_key_for, message) }
      before { redis.set(lock_key, 60) }

      it "does not send a notification" do
        client.should_not_receive(:trigger)
        notifier.notify(message, data)
      end

      context "when a block is given" do
        it "does not execute the block" do
          notifier.notify(message) { fail('should not execute this block') }
        end
      end
    end
  end
end
