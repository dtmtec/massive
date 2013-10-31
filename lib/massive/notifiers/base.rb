module Massive
  module Notifiers
    class Base
      include Massive::Locking

      attr_accessor :id, :last, :options

      def initialize(id, options={})
        self.id   = id
        self.last = {}

        self.options = options
      end

      def notify(message, data=nil, &block)
        send_notification(message, data, &block) unless locked?(message, expiration)
      end

      protected

      def send_notification(message, data, &block)
        data = block.call if block_given?

        self.last = { message: message, data: data }
      end

      def expiration
        options[:expiration] || 1000  # 1 second between each notification
      end
    end
  end
end
