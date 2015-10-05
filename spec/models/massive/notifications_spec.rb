require 'spec_helper'

shared_examples_for Massive::Notifications do
  its(:notifier_id) { is_expected.to eq("#{described_class.name.underscore.gsub('/', '-')}-#{notifyable.id}") }

  after do
    described_class.notifier(:base, {}) # resetting notifier
  end

  describe "#notify(message)" do
    let(:message) { :some_message }
    let(:serializer) { notifyable.active_model_serializer.new(notifyable) }

    it "notifies the message" do
      expect(notifyable.notifier).to receive(:notify).with(message)
      notifyable.notify(message)
    end

    it "sends a serialized version of itself, after reloading itself, as data" do
      notifyable.save
      notifyable.notify(message)
      expect(notifyable.notifier.last[:data].as_json).to eq(serializer.as_json)
    end

    context "when there is no serializer for the step" do
      before { allow(notifyable).to receive(:active_model_serializer).and_return(nil) }

      it "does not sends the notification" do
        expect(notifyable.notifier).to_not receive(:notify)
        notifyable.notify(message)
      end
    end
  end

  describe "#notifier" do
    let(:options) { { expiration: 200, foo: 'bar', other: 'yup' } }

    it "returns an instance of the notifier" do
      expect(notifyable.notifier).to be_a(Massive::Notifiers::Base)
    end

    it "passes notifier options when creating the notifier" do
      described_class.notifier :base, options
      expect(notifyable.notifier.options).to eq(options)
    end

    it "creates it with the notifier_id" do
      expect(notifyable.notifier.id).to eq(notifyable.notifier_id)
    end
  end

  describe ".notifier" do
    context "when a parameter is given" do
      context "as a symbol" do
        it "returns a notifier class from Massive::Notifiers::<given_symbol.camelized>" do
          described_class.notifier :pusher
          expect(described_class.notifier_class).to eq(Massive::Notifiers::Pusher)
        end

        context "and others parameters are given" do
          let(:options) { { expiration: 200, foo: 'bar', other: 'yup' } }

          it "store these parameters to be used when creating the notifier" do
            described_class.notifier :pusher, options
            expect(described_class.notifier_options).to eq(options)
          end
        end
      end

      context "as a Class" do
        it "configures the notifier, using the symbol to get the class" do
          described_class.notifier(Massive::Notifiers::Pusher)
          expect(described_class.notifier_class).to eq(Massive::Notifiers::Pusher)
        end

        context "and others parameters are given" do
          let(:options) { { expiration: 200, foo: 'bar', other: 'yup' } }

          it "passes these parameters when creating the notifier" do
            described_class.notifier(Massive::Notifiers::Pusher, options)
            expect(described_class.notifier_options).to eq(options)
          end
        end
      end
    end
  end
end

describe Massive::Step do
  let(:process) { Massive::Process.new }
  subject(:notifyable) { process.steps.build }

  it_should_behave_like Massive::Notifications
end

describe Massive::Job do
  let(:process) { Massive::Process.new }
  let(:step) { process.steps.build }
  subject(:job) { step.jobs.build }

  let(:message) { 'some message' }

  it "delegates #notify to the step" do
    expect(step).to receive(:notify).with(message)
    job.notify(message)
  end
end
