module Massive
  module Cancelling
    extend ActiveSupport::Concern

    # Override this to provide logic for whether it should be cancelled or not
    def cancelled?
    end

    def cancelling(&block)
      raise Massive::Cancelled.new(cancelled_exception_message) if cancelled?
      block.call
    end

    private

    def cancelled_exception_message
      "Cancelled #{self.class.name} - #{self.id if respond_to?(:id)}"
    end
  end
end
