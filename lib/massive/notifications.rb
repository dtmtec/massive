module Massive
  module Notifications
    extend ActiveSupport::Concern

    included do
      notifier :base
    end

    def notify(message)
      if active_model_serializer
        notifier.notify(message) do
          active_model_serializer.new(reload)
        end
      end
    end

    def notifier
      @notifier ||= self.class.notifier_class.new(notifier_id, self.class.notifier_options)
    end

    def notifier_id
      "#{self.class.name.underscore.gsub('/', '-')}-#{id}"
    end

    module ClassMethods
      def notifier(name, options={})
        @notifier_class = name.is_a?(Class) ? name : "massive/notifiers/#{name}".camelize.constantize
        @notifier_options = options
      end

      def notifier_class
        @notifier_class || Massive::Notifiers::Base
      end

      def notifier_options
        @notifier_options
      end
    end
  end
end
