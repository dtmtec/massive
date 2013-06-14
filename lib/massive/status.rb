module Massive
  module Status
    extend ActiveSupport::Concern

    included do
      field :started_at,  type: Time
      field :finished_at, type: Time
      field :failed_at,   type: Time

      field :last_error,  type: String
      field :retries,     type: Integer, default: 0

      scope :started,       ne(started_at: nil)
      scope :completed,     ne(finished_at: nil)
      scope :not_completed, where(finished_at: nil)
      scope :failed,        ne(failed_at: nil)
    end

    def start!
      update_attributes(attributes_to_reset)
    end

    def started?
      !failed? && started_at?
    end

    def completed?
      !failed? && finished_at?
    end

    def failed?
      failed_at?
    end

    protected

    def attributes_to_reset
      {
        started_at: Time.now,
        finished_at: nil,
        failed_at: nil,
        retries: 0,
        last_error: nil
      }
    end
  end
end
