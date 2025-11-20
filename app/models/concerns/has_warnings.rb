# Provides warning functionality for models
# Warnings are like validations but don't prevent saving
module HasWarnings
  extend ActiveSupport::Concern

  included do
    attr_accessor :warnings_list

    after_validation :check_for_warnings

    def warnings
      @warnings_list ||= []
    end

    def has_warnings?
      warnings.any?
    end

    def add_warning(attribute, message)
      warnings << {attribute: attribute, message: message}
    end

    def warnings_for(attribute)
      warnings.select { |w| w[:attribute] == attribute }.map { |w| w[:message] } # standard:disable Rails/Pluck
    end

    def full_warnings_messages
      warnings.map { |w| "#{w[:attribute].to_s.humanize} #{w[:message]}" }
    end

    private

    def check_for_warnings
      @warnings_list = []
      run_warning_checks if respond_to?(:run_warning_checks, true)
    end
  end
end
