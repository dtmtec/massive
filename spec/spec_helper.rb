require 'simplecov'

SimpleCov.start do
  add_filter 'spec'
end

require 'bundler/setup'

ENV['RACK_ENV'] ||= 'test'

Bundler.require :default, ENV['RACK_ENV']

begin
  require 'byebug'
rescue LoadError
end

root = File.expand_path('../..', __FILE__)

Dir.mkdir("#{root}/tmp") unless File.exists?("#{root}/tmp")
logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new("#{root}/tmp/test.log"))
Mongo::Logger.logger = logger
ActiveJob::Base.logger = logger

Mongoid.load!(File.join(root, "spec/support/mongoid.yml"), :test)

Dir["#{root}/spec/shared/**/*.rb"].each   { |f| require f }
Dir["#{root}/spec/fixtures/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  # config.order = 'random'

  config.before do
    DatabaseCleaner.clean_with('truncation')

    ActiveJob::Base.queue_adapter = :test
  end

  config.before { Massive.redis.flushdb }
  config.after { Massive.redis.flushdb }
end
