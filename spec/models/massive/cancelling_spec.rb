require "spec_helper"

class Cancellable
  include Massive::Cancelling

  attr_accessor :cancelled, :work_count, :work_done_count, :cancelled_exception

  def initialize(work_count)
    self.work_count = work_count
  end

  def cancelled?
    cancelled == true
  end

  def work(&block)
    self.work_done_count = 0

    work_count.times do |iteration|
      cancelling do
        block.call(self, iteration)
        self.work_done_count += 1
      end
    end
  rescue Massive::Cancelled => e
    self.cancelled_exception = e
  end
end

describe Massive::Cancelling do
  let(:work_count) { 3 }
  subject(:cancellable) { Cancellable.new(work_count) }

  context "when it is never cancelled" do
    it "does not cancel the work" do
      cancellable.work { |cancellable| }
      expect(cancellable.work_done_count).to eq(cancellable.work_count)
    end

    it "does not raises a cancelled exception" do
      cancellable.work { |cancellable| }
      expect(cancellable.cancelled_exception).to be_nil
    end
  end

  context "when it is cancelled before actually performing any work" do
    before { cancellable.cancelled = true }

    it "cancels the work before the first iteration" do
      cancellable.work { |cancellable|  }
      expect(cancellable.work_done_count).to eq(0)
    end

    it "raises a cancelled exception" do
      cancellable.work { |cancellable| }
      expect(cancellable.cancelled_exception).to be_present
    end
  end

  context "when it is cancelled while performing some work" do
    it "cancels the work before performing the iteration" do
      cancellable.work { |cancellable, iteration| cancellable.cancelled = (iteration == work_count - 2) }
      expect(cancellable.work_done_count).to eq(2)
    end

    it "raises a cancelled exception" do
      cancellable.work { |cancellable, iteration| cancellable.cancelled = (iteration == work_count - 2) }
      expect(cancellable.cancelled_exception).to be_present
    end
  end

  context "when it is cancelled while performing the last iteration" do
    it "performs all the work" do
      cancellable.work { |cancellable, iteration| cancellable.cancelled = (iteration == work_count - 1) }
      expect(cancellable.work_done_count).to eq(work_count)
    end

    it "does not raise a cancelled exception" do
      cancellable.work { |cancellable, iteration| cancellable.cancelled = (iteration == work_count - 1) }
      expect(cancellable.cancelled_exception).to be_nil
    end
  end
end
