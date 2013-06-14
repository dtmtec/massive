module Massive
  module MemoryConsumption
    extend ActiveSupport::Concern

    included do
      field :memory_consumption, type: Integer, default: 0
    end

    def current_memory_consumption
      IO.popen("ps -o rss= -p #{::Process.pid}") { |io| io.gets.to_i }
    rescue StandardError
      0
    end
  end
end
