module Massive
  module Locking
    def locked?(key, expire_in=60 * 1000)
      lock_key = lock_key_for(key)

      !redis.setnx(lock_key, Time.now.to_i + (expire_in)/1000).tap do |result|
        expire(lock_key, expire_in) if result
      end
    end

    protected

    def lock_key_for(key)
      "#{self.class.name.underscore}:#{id}:#{key}"
    end

    def expire(lock_key, expire_in)
      redis.pexpire(lock_key, expire_in)
    rescue Redis::CommandError
      redis.expire(lock_key, (expire_in/1000).to_i)
    end

    def redis
      @redis ||= Resque.redis
    end
  end
end
