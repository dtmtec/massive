require 'spec_helper'

shared_examples_for Massive::Notifications do
  its(:notifier_id) { should eq("#{described_class.name.underscore.gsub('/', '-')}-#{notifyable.id}") }

  after do
    described_class.notifier(:base, {}) # resetting notifier
  end

  describe "#notify(message)" do
    let(:message) { :some_message }
    let(:serializer) { notifyable.active_model_serializer.new(notifyable) }

    it "notifies the message" do
      notifyable.notifier.should_receive(:notify).with(message)
      notifyable.notify(message)
    end

    it "sends a serialized version of itself, after reloading itself, as data" do
      notifyable.save
      notifyable.notify(message)
      notifyable.notifier.last[:data].as_json.should eq(serializer.as_json)
    end

    context "when there is no serializer for the step" do
      before { notifyable.stub(:active_model_serializer).and_return(nil) }

      it "does not sends the notification" do
        notifyable.notifier.should_not_receive(:notify)
        notifyable.notify(message)
      end
    end
  end

  describe "#notifier" do
    let(:options) { { expiration: 200, foo: 'bar', other: 'yup' } }

    it "returns an instance of the notifier" do
      notifyable.notifier.should be_a(Massive::Notifiers::Base)
    end

    it "passes notifier options when creating the notifier" do
      described_class.notifier :base, options
      notifyable.notifier.options.should eq(options)
    end

    it "creates it with the notifier_id" do
      notifyable.notifier.id.should eq(notifyable.notifier_id)
    end
  end

  describe ".notifier" do
    context "when a parameter is given" do
      context "as a symbol" do
        it "returns a notifier class from Massive::Notifiers::<given_symbol.camelized>" do
          described_class.notifier :pusher
          described_class.notifier_class.should eq(Massive::Notifiers::Pusher)
        end

        context "and others parameters are given" do
          let(:options) { { expiration: 200, foo: 'bar', other: 'yup' } }

          it "store these parameters to be used when creating the notifier" do
            described_class.notifier :pusher, options
            described_class.notifier_options.should eq(options)
          end
        end
      end

      context "as a Class" do
        it "configures the notifier, using the symbol to get the class" do
          described_class.notifier(Massive::Notifiers::Pusher)
          described_class.notifier_class.should eq(Massive::Notifiers::Pusher)
        end

        context "and others parameters are given" do
          let(:options) { { expiration: 200, foo: 'bar', other: 'yup' } }

          it "passes these parameters when creating the notifier" do
            described_class.notifier(Massive::Notifiers::Pusher, options)
            described_class.notifier_options.should eq(options)
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
    step.should_receive(:notify).with(message)
    job.notify(message)
  end
end
