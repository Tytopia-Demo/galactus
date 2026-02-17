# Unified Logging Framework

This document describes the structured JSON logging framework implemented in the Google Auth Library for Ruby.

## Overview

The unified logging framework provides:

- **Structured JSON logging** - All log outputs are formatted as JSON with consistent structure
- **Telemetry context tracking** - Request IDs, user IDs, session IDs, and trace IDs are automatically included
- **Request ID propagation** - Unique request identifiers are generated and can be tracked across the application
- **Log correlation** - Support for distributed tracing with trace and span IDs
- **Metadata enrichment** - Automatic inclusion of timestamp, service name, environment, and version
- **Context preservation** - Telemetry context is maintained across threads and async operations
- **Standardized log levels** - DEBUG, INFO, WARN, ERROR, FATAL

## Usage

### Basic Logging

```ruby
require 'googleauth'

# Use module-level logging
Google::Auth::Logging.info "User authenticated successfully"
Google::Auth::Logging.warn "Token expires soon"
Google::Auth::Logging.error "Authentication failed"
```

### Log Output Format

All logs are output as JSON with the following structure:

```json
{
  "timestamp": "2024-02-17T20:30:45.123Z",
  "severity": "INFO",
  "service": "google-auth-library-ruby",
  "version": "0.13.1",
  "environment": "production",
  "message": "User authenticated successfully",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user-123",
  "session_id": "session-456"
}
```

### Request Context

Set request context to track user operations:

```ruby
# Set request context with user information
Google::Auth::Logging.set_request_context(
  request_id: "req-12345",
  user_id: "user-67890",
  session_id: "session-abcde"
)

# All subsequent logs will include this context
Google::Auth::Logging.info "Processing user request"
```

### Distributed Tracing

For distributed systems, set trace context to correlate logs across services:

```ruby
# Set trace context for distributed tracing
Google::Auth::Logging.set_trace_context(
  trace_id: "trace-xyz",
  span_id: "span-123"
)

Google::Auth::Logging.info "Making external API call"
```

### Context-Aware Logging

Use `with_context` to temporarily override context for a block of code:

```ruby
custom_context = Google::Auth::Logging::TelemetryContext.new
custom_context.user_id = "admin-user"

Google::Auth::Logging.with_context(custom_context) do
  Google::Auth::Logging.info "Admin operation executed"
end
```

### Custom Logger Configuration

Create a custom logger instance with specific configuration:

```ruby
# Configure the global logger
Google::Auth::Logging.configure(
  output: $stdout,
  level: Google::Auth::Logging::Level::DEBUG
)

# Or create a custom logger instance
logger = Google::Auth::Logging.create_logger(
  output: File.open("app.log", "a"),
  level: Google::Auth::Logging::Level::INFO
)

logger.info "Custom logger message"
```

### Environment Configuration

Configure logging behavior via environment variables:

```bash
# Set log level
export GOOGLE_LOG_LEVEL=DEBUG

# Set log format (json or plain)
export GOOGLE_LOG_FORMAT=json

# Set service name
export GOOGLE_SERVICE_NAME=my-auth-service

# Set environment
export GOOGLE_ENVIRONMENT=production
```

### Log Levels

The framework supports standard log levels:

- `DEBUG` - Detailed information for debugging
- `INFO` - General informational messages
- `WARN` - Warning messages for potentially harmful situations
- `ERROR` - Error events that might still allow the application to continue
- `FATAL` - Severe error events that will presumably lead the application to abort

```ruby
# Set log level programmatically
Google::Auth::Logging.logger.level = Google::Auth::Logging::Level::WARN

# Now only WARN, ERROR, and FATAL messages will be logged
Google::Auth::Logging.debug "This won't appear"
Google::Auth::Logging.warn "This will appear"
```

### Logging with Additional Metadata

Add custom metadata to log entries:

```ruby
logger = Google::Auth::Logging.logger
logger.log_with_metadata(
  Google::Auth::Logging::Level::INFO,
  "Token refreshed",
  { token_type: "access_token", expires_in: 3600 }
)
```

## Integration Examples

### Rails Integration

```ruby
# config/initializers/google_auth_logging.rb
require 'googleauth'

Google::Auth::Logging.configure(
  output: Rails.logger,
  level: Rails.env.production? ? Google::Auth::Logging::Level::INFO : Google::Auth::Logging::Level::DEBUG
)
```

### Rack Middleware

```ruby
class GoogleAuthLoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Extract request ID from headers or generate new one
    request_id = env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid

    # Set request context
    Google::Auth::Logging.set_request_context(
      request_id: request_id,
      user_id: env['rack.session']&.[]('user_id')
    )

    @app.call(env)
  end
end

# In your config.ru
use GoogleAuthLoggingMiddleware
```

### Async Operations

Context is preserved across threads:

```ruby
Google::Auth::Logging.set_request_context(request_id: "main-req")

Thread.new do
  # Each thread gets its own context
  Google::Auth::Logging.set_request_context(request_id: "thread-req")
  Google::Auth::Logging.info "Processing in background"
end
```

## Best Practices

1. **Set request context early** - Initialize request context at the beginning of each request
2. **Use appropriate log levels** - Reserve ERROR and FATAL for actual errors
3. **Include relevant metadata** - Add context-specific information to aid debugging
4. **Propagate request IDs** - Pass request IDs between services for correlation
5. **Use structured messages** - Keep log messages consistent and parsable
6. **Avoid logging sensitive data** - Never log credentials, tokens, or personal information

## Log Aggregation and Analysis

The structured JSON format enables easy integration with log aggregation systems:

- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Splunk**
- **Google Cloud Logging**
- **AWS CloudWatch**
- **Datadog**

Example Logstash configuration:

```ruby
input {
  file {
    path => "/var/log/googleauth/*.log"
    codec => "json"
  }
}

filter {
  json {
    source => "message"
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "googleauth-logs-%{+YYYY.MM.dd}"
  }
}
```

## Troubleshooting

### Logs not appearing

Check the log level:

```ruby
puts Google::Auth::Logging.logger.level
# Ensure it's at the appropriate level for your messages
```

### Context not being included

Verify context is set before logging:

```ruby
Google::Auth::Logging.set_request_context(request_id: "test")
context = Thread.current[:telemetry_context]
puts context.to_h.inspect
```

### JSON parsing errors

Ensure output is captured correctly and complete log lines are being read:

```ruby
# Read complete lines
File.foreach("app.log") do |line|
  log_entry = JSON.parse(line)
  puts log_entry
end
```

## Migration Guide

If you were using custom logging before, here's how to migrate:

### Before

```ruby
puts "Warning: Token expires soon"
warn "Authentication failed"
```

### After

```ruby
Google::Auth::Logging.warn "Token expires soon"
Google::Auth::Logging.error "Authentication failed"
```

The new logging system automatically adds structure, context, and metadata to all log entries.
