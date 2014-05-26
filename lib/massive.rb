require "massive/version"

module Massive
  autoload :MemoryConsumption, 'massive/memory_consumption'
  autoload :TimingSupport,     'massive/timing_support'
  autoload :Status,            'massive/status'
  autoload :Locking,           'massive/locking'
  autoload :Retry,             'massive/retry'
  autoload :Cancelling,        'massive/cancelling'

  autoload :Process,           'massive/process'
  autoload :Step,              'massive/step'
  autoload :Job,               'massive/job'

  autoload :File,              'massive/file'
  autoload :FileProcess,       'massive/file_process'
  autoload :FileStep,          'massive/file_step'
  autoload :FileJob,           'massive/file_job'

  autoload :Notifications,     'massive/notifications'
  autoload :Notifiers,         'massive/notifiers'

  autoload :ProcessSerializer, 'massive/process_serializer'
  autoload :StepSerializer,    'massive/step_serializer'

  module Authenticators
    autoload :S3,              'massive/authenticators/s3'
  end

  class Cancelled < StandardError; end

  def self.redis
    @redis ||= Resque.redis
  end

  def self.split_jobs
    @split_jobs
  end

  def self.split_jobs=(value)
    @split_jobs = value
  end

  def self.storage_config
    @storage_config
  end

  def self.storage_config=(value)
    @storage_config ||= {}
    @storage_config.merge!(value)
  end

  self.storage_config = {
    directory: 'massive',
    provider: Massive::Authenticators::S3,
    key: nil,
    secret: nil,
    expiration: 1 * 60 * 60 # 1 hour
  }
end

require "resque"
require "mongoid"
require "active_model_serializers"
require "file_processor"
