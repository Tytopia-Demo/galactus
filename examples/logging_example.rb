#!/usr/bin/env ruby
# Copyright 2024, Google Inc.
# All rights reserved.
#
# Example demonstrating the unified logging framework

require_relative '../lib/googleauth'
require 'json'

puts "=" * 80
puts "Google Auth Library - Unified Logging Framework Example"
puts "=" * 80
puts

# 1. Basic Structured Logging
puts "1. Basic Structured Logging:"
puts "-" * 40

Google::Auth::Logging.configure(
  output: $stdout,
  level: Google::Auth::Logging::Level::DEBUG
)

Google::Auth::Logging.debug "This is a debug message"
Google::Auth::Logging.info "This is an info message"
Google::Auth::Logging.warn "This is a warning message"
puts

# 2. Request Context Tracking
puts "2. Request Context Tracking:"
puts "-" * 40

Google::Auth::Logging.set_request_context(
  request_id: "req-12345-example",
  user_id: "user-67890",
  session_id: "session-abcde"
)

Google::Auth::Logging.info "User authentication initiated"
Google::Auth::Logging.info "Token validation successful"
puts

# 3. Distributed Tracing
puts "3. Distributed Tracing Support:"
puts "-" * 40

Google::Auth::Logging.set_trace_context(
  trace_id: "trace-xyz-789",
  span_id: "span-abc-123"
)

Google::Auth::Logging.info "External API call started"
Google::Auth::Logging.info "External API call completed"
puts

# 4. Context-Aware Logging
puts "4. Context-Aware Logging:"
puts "-" * 40

admin_context = Google::Auth::Logging::TelemetryContext.new
admin_context.user_id = "admin-user"
admin_context.session_id = "admin-session"

Google::Auth::Logging.with_context(admin_context) do
  Google::Auth::Logging.warn "Admin operation: deleting expired tokens"
end
puts

# 5. Logging with Metadata
puts "5. Logging with Additional Metadata:"
puts "-" * 40

logger = Google::Auth::Logging.logger
logger.log_with_metadata(
  Google::Auth::Logging::Level::INFO,
  "Token refresh completed",
  {
    token_type: "access_token",
    expires_in: 3600,
    scope: "https://www.googleapis.com/auth/cloud-platform"
  }
)
puts

# 6. Error Logging
puts "6. Error Logging:"
puts "-" * 40

begin
  raise StandardError, "Simulated authentication error"
rescue => e
  Google::Auth::Logging.error e
end
puts

# 7. Different Log Levels
puts "7. Demonstrating Log Level Filtering:"
puts "-" * 40

puts "Setting log level to WARN (only WARN, ERROR, FATAL will show):"
Google::Auth::Logging.logger.level = Google::Auth::Logging::Level::WARN

Google::Auth::Logging.debug "This debug won't show"
Google::Auth::Logging.info "This info won't show"
Google::Auth::Logging.warn "This warning will show"
Google::Auth::Logging.error "This error will show"
puts

# Reset to INFO level
Google::Auth::Logging.logger.level = Google::Auth::Logging::Level::INFO

# 8. Current Request ID
puts "8. Request ID Tracking:"
puts "-" * 40
request_id = Google::Auth::Logging.current_request_id
puts "Current request ID: #{request_id}"
puts

# 9. Thread Safety
puts "9. Thread Safety and Context Isolation:"
puts "-" * 40

Google::Auth::Logging.set_request_context(request_id: "main-thread-req")

thread = Thread.new do
  Google::Auth::Logging.set_request_context(request_id: "child-thread-req")
  Google::Auth::Logging.info "Logging from child thread"
end
thread.join

Google::Auth::Logging.info "Logging from main thread"
puts

puts "=" * 80
puts "Example completed successfully!"
puts "=" * 80
puts
puts "Key Features Demonstrated:"
puts "  ✓ Structured JSON logging with consistent format"
puts "  ✓ Request ID generation and propagation"
puts "  ✓ Telemetry context (user, session, trace, span)"
puts "  ✓ Log correlation for distributed systems"
puts "  ✓ Metadata enrichment (timestamp, service, environment)"
puts "  ✓ Context preservation across threads"
puts "  ✓ Standardized log levels (DEBUG, INFO, WARN, ERROR, FATAL)"
puts "  ✓ Thread-safe context management"
puts
