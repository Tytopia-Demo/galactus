# Copyright 2024, Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require "json"
require "securerandom"
require "logger"

module Google
  module Auth
    # Unified logging framework for Google Auth Library
    # Provides structured JSON logging with telemetry context tracking
    module Logging
      # Log levels aligned with standard severity levels
      module Level
        DEBUG = ::Logger::DEBUG
        INFO = ::Logger::INFO
        WARN = ::Logger::WARN
        ERROR = ::Logger::ERROR
        FATAL = ::Logger::FATAL
        UNKNOWN = ::Logger::UNKNOWN
      end

      # Telemetry context for tracking request flow
      class TelemetryContext
        attr_accessor :request_id, :user_id, :session_id, :trace_id, :span_id

        def initialize
          @request_id = generate_request_id
          @user_id = nil
          @session_id = nil
          @trace_id = nil
          @span_id = nil
        end

        def to_h
          {
            request_id: @request_id,
            user_id: @user_id,
            session_id: @session_id,
            trace_id: @trace_id,
            span_id: @span_id
          }.compact
        end

        private

        def generate_request_id
          SecureRandom.uuid
        end
      end

      # JSON formatter for structured logging
      class JsonFormatter < ::Logger::Formatter
        def call severity, time, progname, msg
          log_entry = {
            timestamp: time.utc.iso8601(3),
            severity: severity,
            service: service_name,
            version: Google::Auth::VERSION,
            environment: environment,
            message: msg2str(msg)
          }

          # Add telemetry context if available
          if Thread.current[:telemetry_context]
            log_entry.merge! Thread.current[:telemetry_context].to_h
          end

          # Add progname if present
          log_entry[:component] = progname if progname

          JSON.generate(log_entry) + "\n"
        end

        private

        def msg2str msg
          case msg
          when ::String
            msg
          when ::Exception
            "#{msg.message} (#{msg.class})\n" \
            "#{(msg.backtrace || []).join("\n")}"
          else
            msg.inspect
          end
        end

        def service_name
          ENV["GOOGLE_SERVICE_NAME"] || "google-auth-library-ruby"
        end

        def environment
          ENV["GOOGLE_ENVIRONMENT"] || ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
        end
      end

      # Main logger class with context support
      class StructuredLogger
        attr_reader :logger
        attr_accessor :telemetry_context

        def initialize output: $stderr, level: Level::INFO, formatter: nil
          @logger = ::Logger.new output
          @logger.level = level
          @logger.formatter = formatter || JsonFormatter.new
          @telemetry_context = TelemetryContext.new
        end

        # Set telemetry context for current thread
        def with_context context = nil
          old_context = Thread.current[:telemetry_context]
          Thread.current[:telemetry_context] = context || @telemetry_context
          yield
        ensure
          Thread.current[:telemetry_context] = old_context
        end

        # Set request context
        def set_request_context request_id: nil, user_id: nil, session_id: nil
          context = Thread.current[:telemetry_context] || TelemetryContext.new
          context.request_id = request_id if request_id
          context.user_id = user_id if user_id
          context.session_id = session_id if session_id
          Thread.current[:telemetry_context] = context
        end

        # Set trace context for distributed tracing
        def set_trace_context trace_id: nil, span_id: nil
          context = Thread.current[:telemetry_context] || TelemetryContext.new
          context.trace_id = trace_id if trace_id
          context.span_id = span_id if span_id
          Thread.current[:telemetry_context] = context
        end

        # Get current request ID
        def current_request_id
          context = Thread.current[:telemetry_context]
          context&.request_id || @telemetry_context.request_id
        end

        # Standard log level methods
        def debug message = nil, &block
          @logger.debug message, &block
        end

        def info message = nil, &block
          @logger.info message, &block
        end

        def warn message = nil, &block
          @logger.warn message, &block
        end

        def error message = nil, &block
          @logger.error message, &block
        end

        def fatal message = nil, &block
          @logger.fatal message, &block
        end

        # Log with additional metadata
        def log_with_metadata level, message, metadata = {}
          enriched_message = if metadata.empty?
                               message
                             else
                               "#{message} | metadata: #{JSON.generate(metadata)}"
                             end
          @logger.add level, enriched_message
        end

        # Change log level
        def level= level
          @logger.level = level
        end

        def level
          @logger.level
        end
      end

      class << self
        attr_writer :logger

        # Get the global logger instance
        def logger
          @logger ||= create_default_logger
        end

        # Create a new logger instance
        def create_logger output: $stderr, level: Level::INFO, formatter: nil
          StructuredLogger.new output: output, level: level, formatter: formatter
        end

        # Configure global logger
        def configure output: nil, level: nil, formatter: nil
          @logger = StructuredLogger.new(
            output: output || $stderr,
            level: level || default_log_level,
            formatter: formatter || default_formatter
          )
        end

        # Reset to default logger
        def reset!
          @logger = create_default_logger
        end

        # Convenience methods for logging
        def debug message = nil, &block
          logger.debug message, &block
        end

        def info message = nil, &block
          logger.info message, &block
        end

        def warn message = nil, &block
          logger.warn message, &block
        end

        def error message = nil, &block
          logger.error message, &block
        end

        def fatal message = nil, &block
          logger.fatal message, &block
        end

        # Context management
        def with_context context = nil, &block
          logger.with_context context, &block
        end

        def set_request_context request_id: nil, user_id: nil, session_id: nil
          logger.set_request_context(
            request_id: request_id,
            user_id: user_id,
            session_id: session_id
          )
        end

        def set_trace_context trace_id: nil, span_id: nil
          logger.set_trace_context trace_id: trace_id, span_id: span_id
        end

        def current_request_id
          logger.current_request_id
        end

        private

        def create_default_logger
          StructuredLogger.new(
            output: $stderr,
            level: default_log_level,
            formatter: default_formatter
          )
        end

        def default_log_level
          level_name = ENV["GOOGLE_LOG_LEVEL"] || "INFO"
          Level.const_get(level_name.upcase)
        rescue NameError
          Level::INFO
        end

        def default_formatter
          format_type = ENV["GOOGLE_LOG_FORMAT"] || "json"
          case format_type.downcase
          when "json"
            JsonFormatter.new
          else
            nil # Use default Logger formatter
          end
        end
      end
    end
  end
end
