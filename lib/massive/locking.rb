module Massive
  module Locking
    def locked?(key)
      lock_key = lock_key_for(key)

      !redis.setnx(lock_key, 1.minute.from_now).tap do |result|
        redis.expire(lock_key, 1.minute) if result
      end
    end

    protected

    def lock_key_for(key)
      "#{self.class.name.underscore}:#{id}:#{key}"
    end

    def redis
      @redis ||= Resque.redis
    end
  end
end
