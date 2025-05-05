# typed: false
# frozen_string_literal: true

require "rspec/rails/feature_check"
require "active_support/error_reporter"
require "active_support/core_ext/hash/indifferent_access"

# Define Rails module if it doesn't exist so we can test the matcher
unless defined?(Rails) && Rails.respond_to?(:error)
  module Rails
    class << self
      def error
        @error_reporter ||= ActiveSupport::ErrorReporter.new
      end
    end
  end
end

RSpec.describe "have_reported_error" do
  # Custom error class for testing
  class CustomError < StandardError; end
  
  before do
    # Reset error events before each test
    Rails.error.instance_variable_set(:@subscribers, [])
  end

  context "with no arguments" do
    it "matches when any error is reported" do
      expect do
        Rails.error.report(StandardError.new("An error occurred"))
      end.to have_reported_error
    end

    it "doesn't match when no error is reported" do
      expect do
        # No error reported
      end.not_to have_reported_error
    end
  end

  context "with error class argument" do
    it "matches when error of specified class is reported" do
      expect do
        Rails.error.report(CustomError.new("A custom error"))
      end.to have_reported_error(CustomError)
    end

    it "doesn't match when error of different class is reported" do
      expect do
        Rails.error.report(StandardError.new("A standard error"))
      end.not_to have_reported_error(CustomError)
    end
  end

  context "with error instance argument" do
    it "matches when error of same class and message is reported" do
      expect do
        Rails.error.report(CustomError.new("A specific message"))
      end.to have_reported_error(CustomError.new("A specific message"))
    end

    it "matches when error of same class is reported and no message specified" do
      expect do
        Rails.error.report(CustomError.new("Any message"))
      end.to have_reported_error(CustomError.new(""))
    end

    it "doesn't match when error message differs" do
      expect do
        Rails.error.report(CustomError.new("A different message"))
      end.not_to have_reported_error(CustomError.new("A specific message"))
    end
  end

  context "with regexp argument" do
    it "matches when error message matches the regexp" do
      expect do
        Rails.error.report(StandardError.new("This contains important details"))
      end.to have_reported_error(/important details/)
    end

    it "doesn't match when error message doesn't match the regexp" do
      expect do
        Rails.error.report(StandardError.new("A completely different message"))
      end.not_to have_reported_error(/important details/)
    end
  end

  context "with attributes" do
    it "matches when attributes match" do
      expect do
        Rails.error.report(StandardError.new("Error with context"), user_id: 42, source: "test")
      end.to have_reported_error(StandardError).with(user_id: 42)
    end

    it "doesn't match when attributes don't match" do
      expect do
        Rails.error.report(StandardError.new("Error with context"), user_id: 99, source: "test")
      end.not_to have_reported_error.with(user_id: 42)
    end
  end
end