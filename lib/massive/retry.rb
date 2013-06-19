module Massive
  module Retry
    extend ActiveSupport::Concern

    included do
      retry_interval 2
      maximum_retries 10

      def self.inherited(base)
        super

        base.retry_interval retry_interval
        base.maximum_retries maximum_retries
      end
    end

    def retrying(&block)
      self.retries = 0

      begin
        block.call
      rescue SignalException => e
        raise e # when the process is being terminated, there is no need to retry it
      rescue StandardError => e
        self.retries += 1

        if self.retries < self.class.maximum_retries
          Kernel.sleep self.class.retry_interval
          retry
        else
          raise e
        end
      end
    end

    module ClassMethods
      def retry_interval(value=nil)
        @retry_interval = value if value
        @retry_interval
      end

      def maximum_retries(value=nil)
        @maximum_retries = value if value
        @maximum_retries
      end
    end
  end
end
