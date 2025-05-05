module RSpec
  module Rails
    module Matchers
      # @api public
      # Matcher for checking if an error was reported to ActiveSupport::ErrorReporter.
      #
      # @example
      #   expect { code_that_reports_error }.to have_reported_error
      #   expect { code_that_reports_error }.to have_reported_error(ErrorClass)
      #   expect { code_that_reports_error }.to have_reported_error(ErrorClass.new("message"))
      #   expect { code_that_reports_error }.to have_reported_error(/pattern/)
      #   expect { code_that_reports_error }.to have_reported_error.with(context: "value")
      class HaveReportedError < RSpec::Rails::Matchers::BaseMatcher
        # @api private
        # Error subscriber for capturing errors reported to Rails.error
        class ErrorSubscriber
          attr_reader :events

          def initialize
            @events = []
          end

          def report(error, **attrs)
            @events << [error, attrs]
          end
        end

        # @api public
        # Initialize the matcher with optional expected error.
        #
        # @param expected_error [Class, Exception, Regexp, Symbol, nil] expected error
        def initialize(expected_error = nil)
          @expected_error = expected_error
          @attributes = {}
        end

        # @api public
        # Specify additional attributes expected in the error report.
        #
        # @example
        #   expect { code }.to have_reported_error.with(user_id: 123)
        #
        # @param expected_attributes [Hash] expected error attributes
        # @return [HaveReportedError] self
        def with(expected_attributes)
          @attributes.merge!(expected_attributes)
          self
        end

        # @api private
        # Match the reported error against expectations.
        #
        # @param block [Proc] block that should report an error
        # @return [Boolean] true if expectations are met
        def matches?(block)
          @error_subscriber = ErrorSubscriber.new
          ::Rails.error.subscribe(@error_subscriber)

          block.call if block

          case @expected_error
          when Class
            return false unless actual_error.is_a?(@expected_error)
          when Exception
            return false unless actual_error.is_a?(@expected_error.class)
            unless @expected_error.message.empty?
              return false unless actual_error.message == @expected_error.message
            end
          when nil
            return false unless @error_subscriber.events.count == 1
          when Regexp
            return false unless actual_error.message.match?(@expected_error)
          when Symbol
            return false unless actual_error == @expected_error
          end

          if !@attributes.empty? && !@error_subscriber.events.empty?
            event_data = @error_subscriber.events.last[1]
            return attributes_match?(event_data)
          end

          true
        ensure
          ::Rails.error.unsubscribe(@error_subscriber) if defined?(@error_subscriber)
        end

        # @api private
        # This matcher supports block expectations.
        #
        # @return [Boolean] true
        def supports_block_expectations?
          true
        end

        # @api private
        # Descriptive failure message.
        #
        # @return [String] failure message
        def failure_message
          if @error_subscriber.events.empty?
            'Expected the block to report an error, but none was reported.'
          elsif !@attributes.empty?
            event_data = @error_subscriber.events.last[1].with_indifferent_access
            unmatched = unmatched_attributes(event_data)
            unless unmatched.empty?
              "Expected error attributes to match #{@attributes}, but got these mismatches: #{unmatched} and actual values are #{event_data}"
            end
          else
            case @expected_error
            when Class
              "Expected error to be an instance of #{@expected_error}, but got #{actual_error.class} with message: '#{actual_error.message}'"
            when Exception
              "Expected error to be #{@expected_error.class} with message '#{@expected_error.message}', but got #{actual_error.class} with message: '#{actual_error.message}'"
            when Regexp
              "Expected error message to match #{@expected_error}, but got: '#{actual_error.message}'"
            when Symbol
              "Expected error to be #{@expected_error}, but got: #{actual_error}"
            else
              "Expected specific error, but got #{actual_error.class} with message: '#{actual_error.message}'"
            end
          end
        end

        # @api private
        # Failure message when expectation is negated.
        #
        # @return [String] negated failure message
        def failure_message_when_negated
          error_count = @error_subscriber.events.count
          "Expected the block not to report any errors, but #{error_count} #{'error'.pluralize(error_count)} #{error_count == 1 ? 'has' : 'have'} been reported."
        end

        private

        # @api private
        # Get the actual reported error from the subscriber.
        #
        # @return [Object, nil] the error that was reported or nil
        def actual_error
          @error_subscriber.events.empty? ? nil : @error_subscriber.events.last[0]
        end

        # @api private
        # Check if all expected attributes match the actual attributes.
        #
        # @param actual [Hash] actual error attributes
        # @return [Boolean] true if all expected attributes match
        def attributes_match?(actual)
          @attributes.all? do |key, value|
            values_match?(value, actual[key])
          end
        end

        # @api private
        # Get a list of expected attributes that don't match actual attributes.
        #
        # @param actual [Hash] actual error attributes
        # @return [Hash] unmatched attributes
        def unmatched_attributes(actual)
          @attributes.reject do |key, value|
            values_match?(value, actual[key])
          end
        end
      end

      # @api public
      # Passes if ActiveSupport::ErrorReporter received an error report.
      #
      # @example
      #   expect { code_that_reports_errors }.to have_reported_error
      #   expect { code_that_reports_errors }.to have_reported_error(CustomError)
      #   expect { code_that_reports_errors }.to have_reported_error(CustomError.new("message"))
      #
      # @param expected_error [Class, Exception, Regexp, Symbol, nil] expected error
      # @return [HaveReportedError] a matcher instance
      def have_reported_error(expected_error = nil)
        HaveReportedError.new(expected_error)
      end
    end
  end
end
