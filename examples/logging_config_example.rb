#!/usr/bin/env ruby
# Copyright 2024, Google Inc.
# All rights reserved.
#
# Example configuration patterns for the unified logging framework

require_relative '../lib/googleauth'

puts "Google Auth Library - Logging Configuration Examples"
puts "=" * 80
puts

# Example 1: Production configuration with JSON logging
puts "Example 1: Production JSON Logging to File"
puts "-" * 40

log_file = File.open('/tmp/googleauth-production.log', 'a')
Google::Auth::Logging.configure(
  output: log_file,
  level: Google::Auth::Logging::Level::INFO,
  formatter: Google::Auth::Logging::JsonFormatter.new
)

Google::Auth::Logging.info "Production logging configured"
puts "✓ Logs written to /tmp/googleauth-production.log"
puts

# Example 2: Development configuration with debug level
puts "Example 2: Development Configuration"
puts "-" * 40

Google::Auth::Logging.configure(
  output: $stdout,
  level: Google::Auth::Logging::Level::DEBUG
)

Google::Auth::Logging.debug "Debug logging enabled for development"
puts

# Example 3: Custom logger instance for specific operations
puts "Example 3: Custom Logger Instance"
puts "-" * 40

audit_log = File.open('/tmp/googleauth-audit.log', 'a')
audit_logger = Google::Auth::Logging.create_logger(
  output: audit_log,
  level: Google::Auth::Logging::Level::INFO,
  formatter: Google::Auth::Logging::JsonFormatter.new
)

audit_logger.info "Audit event: User authentication"
puts "✓ Audit logs written to /tmp/googleauth-audit.log"
puts

# Example 4: Environment-based configuration
puts "Example 4: Environment-Based Configuration"
puts "-" * 40

# Simulating environment variables
ENV['GOOGLE_LOG_LEVEL'] = 'DEBUG'
ENV['GOOGLE_SERVICE_NAME'] = 'my-auth-service'
ENV['GOOGLE_ENVIRONMENT'] = 'staging'

# Reset to pick up environment variables
Google::Auth::Logging.reset!

Google::Auth::Logging.info "Configuration loaded from environment"
puts "✓ Log level: DEBUG"
puts "✓ Service name: my-auth-service"
puts "✓ Environment: staging"
puts

# Clean up environment variables
ENV.delete('GOOGLE_LOG_LEVEL')
ENV.delete('GOOGLE_SERVICE_NAME')
ENV.delete('GOOGLE_ENVIRONMENT')

# Example 5: Separate loggers for different concerns
puts "Example 5: Multiple Logger Instances"
puts "-" * 40

# Security events logger
security_logger = Google::Auth::Logging.create_logger(
  output: File.open('/tmp/security.log', 'a'),
  level: Google::Auth::Logging::Level::WARN
)

# Performance metrics logger
performance_logger = Google::Auth::Logging.create_logger(
  output: File.open('/tmp/performance.log', 'a'),
  level: Google::Auth::Logging::Level::INFO
)

security_logger.warn "Failed authentication attempt detected"
performance_logger.info "Token fetch completed in 150ms"

puts "✓ Security logs: /tmp/security.log"
puts "✓ Performance logs: /tmp/performance.log"
puts

# Example 6: Integration with Rails logger
puts "Example 6: Rails Integration Pattern"
puts "-" * 40

# In a Rails application, you would do:
# Google::Auth::Logging.configure(
#   output: Rails.logger,
#   level: Rails.env.production? ?
#     Google::Auth::Logging::Level::INFO :
#     Google::Auth::Logging::Level::DEBUG
# )

puts <<~RAILS
  # config/initializers/google_auth.rb
  Google::Auth::Logging.configure(
    output: Rails.logger,
    level: Rails.env.production? ?
      Google::Auth::Logging::Level::INFO :
      Google::Auth::Logging::Level::DEBUG
  )

  # Set request context in a before_action
  class ApplicationController < ActionController::Base
    before_action :set_logging_context

    private

    def set_logging_context
      Google::Auth::Logging.set_request_context(
        request_id: request.request_id,
        user_id: current_user&.id,
        session_id: session.id
      )
    end
  end
RAILS
puts

# Example 7: Log rotation configuration
puts "Example 7: Log Rotation Pattern"
puts "-" * 40

puts <<~ROTATION
  require 'logger'

  # Create a rotating log file (shifts when it reaches 10MB, keeps 5 old files)
  rotating_logger = Logger.new(
    '/var/log/googleauth/app.log',
    5,                    # keep 5 old log files
    10 * 1024 * 1024     # rotate when log reaches 10MB
  )

  Google::Auth::Logging.configure(
    output: rotating_logger,
    level: Google::Auth::Logging::Level::INFO
  )
ROTATION
puts

# Cleanup
log_file.close if log_file && !log_file.closed?
audit_log.close if audit_log && !audit_log.closed?

puts "=" * 80
puts "Configuration examples completed!"
puts "All example log files have been created in /tmp/"
puts
