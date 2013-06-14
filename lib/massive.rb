require "massive/version"

module Massive
  autoload :MemoryConsumption, 'massive/memory_consumption'
  autoload :TimingSupport,     'massive/timing_support'
  autoload :Status,            'massive/status'
  autoload :Locking,           'massive/locking'
  autoload :Retry,             'massive/retry'

  autoload :Process,           'massive/process'
  autoload :Step,              'massive/step'
  autoload :Job,               'massive/job'

  autoload :File,              'massive/file'
  autoload :FileProcess,       'massive/file_process'
  autoload :FileStep,          'massive/file_step'
  autoload :FileJob,           'massive/file_job'
end

require "resque"
require "mongoid"
require "file_processor"
