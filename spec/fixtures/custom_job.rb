class CustomJob < Massive::Job
  retry_interval 5
  maximum_retries 20
end
