module Massive
  module Notifiers
    class Pusher < Base
      protected

      def send_notification(message, data, &block)
        data = block.call if block_given?

        client.trigger(id, message, data)
      rescue RuntimeError
      end

      def client
        @client ||= options[:client] || ::Pusher
      end
    end
  end
end
