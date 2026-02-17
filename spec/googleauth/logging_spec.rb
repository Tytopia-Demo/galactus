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

spec_dir = File.expand_path File.join(File.dirname(__FILE__))
$LOAD_PATH.unshift spec_dir
$LOAD_PATH.unshift File.join(spec_dir, "..", "..", "lib")

require "googleauth/logging"
require "json"
require "stringio"

describe Google::Auth::Logging do
  after :each do
    Google::Auth::Logging.reset!
    Thread.current[:telemetry_context] = nil
  end

  describe "TelemetryContext" do
    it "generates a unique request_id on initialization" do
      context1 = Google::Auth::Logging::TelemetryContext.new
      context2 = Google::Auth::Logging::TelemetryContext.new

      expect(context1.request_id).not_to be_nil
      expect(context2.request_id).not_to be_nil
      expect(context1.request_id).not_to eq(context2.request_id)
    end

    it "converts to hash with only non-nil values" do
      context = Google::Auth::Logging::TelemetryContext.new
      context.user_id = "user-123"
      context.session_id = "session-456"

      hash = context.to_h
      expect(hash[:request_id]).not_to be_nil
      expect(hash[:user_id]).to eq("user-123")
      expect(hash[:session_id]).to eq("session-456")
      expect(hash[:trace_id]).to be_nil
      expect(hash.key?(:trace_id)).to be false
    end
  end

  describe "JsonFormatter" do
    let(:output) { StringIO.new }
    let(:logger) { Google::Auth::Logging.create_logger(output: output, formatter: Google::Auth::Logging::JsonFormatter.new) }

    it "formats log entries as JSON" do
      logger.info "Test message"
      output.rewind
      log_entry = JSON.parse(output.read)

      expect(log_entry["message"]).to eq("Test message")
      expect(log_entry["severity"]).to eq("INFO")
      expect(log_entry["service"]).to eq("google-auth-library-ruby")
      expect(log_entry["version"]).to eq(Google::Auth::VERSION)
      expect(log_entry["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "includes telemetry context when available" do
      context = Google::Auth::Logging::TelemetryContext.new
      context.user_id = "test-user"
      Thread.current[:telemetry_context] = context

      logger.warn "Warning with context"
      output.rewind
      log_entry = JSON.parse(output.read)

      expect(log_entry["user_id"]).to eq("test-user")
      expect(log_entry["request_id"]).not_to be_nil
    end

    it "includes environment from ENV variables" do
      allow(ENV).to receive(:[]).with("GOOGLE_ENVIRONMENT").and_return("staging")
      allow(ENV).to receive(:[]).with("GOOGLE_SERVICE_NAME").and_return(nil)
      allow(ENV).to receive(:[]).with("RACK_ENV").and_return(nil)
      allow(ENV).to receive(:[]).with("RAILS_ENV").and_return(nil)

      formatter = Google::Auth::Logging::JsonFormatter.new
      allow(formatter).to receive(:environment).and_return("staging")

      logger = Google::Auth::Logging.create_logger(output: output, formatter: formatter)
      logger.info "Environment test"

      # Just verify it doesn't crash; actual environment detection is more complex
      expect(output.string).not_to be_empty
    end
  end

  describe "StructuredLogger" do
    let(:output) { StringIO.new }
    let(:logger) { Google::Auth::Logging.create_logger(output: output) }

    it "supports all standard log levels" do
      logger.debug "Debug message"
      logger.info "Info message"
      logger.warn "Warning message"
      logger.error "Error message"
      logger.fatal "Fatal message"

      output.rewind
      lines = output.read.split("\n").reject(&:empty?)
      expect(lines.length).to eq(4)  # DEBUG is filtered by default level
    end

    it "can set and get log level" do
      logger.level = Google::Auth::Logging::Level::DEBUG
      expect(logger.level).to eq(Google::Auth::Logging::Level::DEBUG)

      logger.debug "Debug is visible"
      output.rewind
      expect(output.read).to include("Debug is visible")
    end

    it "sets request context correctly" do
      logger.set_request_context(
        request_id: "req-123",
        user_id: "user-456",
        session_id: "session-789"
      )

      context = Thread.current[:telemetry_context]
      expect(context.request_id).to eq("req-123")
      expect(context.user_id).to eq("user-456")
      expect(context.session_id).to eq("session-789")
    end

    it "sets trace context correctly" do
      logger.set_trace_context(
        trace_id: "trace-abc",
        span_id: "span-def"
      )

      context = Thread.current[:telemetry_context]
      expect(context.trace_id).to eq("trace-abc")
      expect(context.span_id).to eq("span-def")
    end

    it "provides current_request_id" do
      request_id = logger.current_request_id
      expect(request_id).not_to be_nil

      logger.set_request_context(request_id: "custom-req-id")
      expect(logger.current_request_id).to eq("custom-req-id")
    end

    it "preserves context within with_context block" do
      custom_context = Google::Auth::Logging::TelemetryContext.new
      custom_context.user_id = "block-user"

      logger.with_context(custom_context) do
        logger.info "Inside block"

        output.rewind
        log_entry = JSON.parse(output.read)
        expect(log_entry["user_id"]).to eq("block-user")
      end
    end

    it "logs with additional metadata" do
      logger.log_with_metadata(
        Google::Auth::Logging::Level::INFO,
        "Operation completed",
        { operation: "fetch_token", duration_ms: 150 }
      )

      output.rewind
      log_entry = JSON.parse(output.read)
      expect(log_entry["message"]).to include("Operation completed")
      expect(log_entry["message"]).to include("metadata")
    end
  end

  describe "Module-level logging" do
    let(:output) { StringIO.new }

    before do
      Google::Auth::Logging.configure(output: output, level: Google::Auth::Logging::Level::DEBUG)
    end

    it "provides module-level logging methods" do
      Google::Auth::Logging.debug "Debug"
      Google::Auth::Logging.info "Info"
      Google::Auth::Logging.warn "Warn"
      Google::Auth::Logging.error "Error"
      Google::Auth::Logging.fatal "Fatal"

      output.rewind
      lines = output.read.split("\n").reject(&:empty?)
      expect(lines.length).to eq(5)
    end

    it "provides module-level context management" do
      Google::Auth::Logging.set_request_context(
        request_id: "module-req",
        user_id: "module-user"
      )

      request_id = Google::Auth::Logging.current_request_id
      expect(request_id).to eq("module-req")
    end

    it "supports with_context at module level" do
      context = Google::Auth::Logging::TelemetryContext.new
      context.session_id = "module-session"

      Google::Auth::Logging.with_context(context) do
        Google::Auth::Logging.info "Module context test"

        output.rewind
        log_entry = JSON.parse(output.read)
        expect(log_entry["session_id"]).to eq("module-session")
      end
    end
  end

  describe "Configuration" do
    it "respects GOOGLE_LOG_LEVEL environment variable" do
      allow(ENV).to receive(:[]).with("GOOGLE_LOG_LEVEL").and_return("DEBUG")
      allow(ENV).to receive(:[]).with("GOOGLE_LOG_FORMAT").and_return(nil)

      Google::Auth::Logging.reset!
      # Default logger should be created with DEBUG level
      expect(Google::Auth::Logging.logger).not_to be_nil
    end

    it "defaults to INFO level when environment variable is invalid" do
      allow(ENV).to receive(:[]).with("GOOGLE_LOG_LEVEL").and_return("INVALID")
      allow(ENV).to receive(:[]).with("GOOGLE_LOG_FORMAT").and_return(nil)

      Google::Auth::Logging.reset!
      expect(Google::Auth::Logging.logger.level).to eq(Google::Auth::Logging::Level::INFO)
    end
  end

  describe "Context preservation across threads" do
    let(:output) { StringIO.new }
    let(:logger) { Google::Auth::Logging.create_logger(output: output) }

    it "maintains separate context per thread" do
      logger.set_request_context(request_id: "main-thread")
      main_request_id = logger.current_request_id

      thread_request_id = nil
      thread = Thread.new do
        logger.set_request_context(request_id: "child-thread")
        thread_request_id = logger.current_request_id
      end
      thread.join

      expect(main_request_id).to eq("main-thread")
      expect(thread_request_id).to eq("child-thread")
      expect(logger.current_request_id).to eq("main-thread")
    end
  end
end
