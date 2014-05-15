class CustomJob < Massive::Job
  include Mongoid::Attributes::Dynamic

  retry_interval 5
  maximum_retries 20
end
