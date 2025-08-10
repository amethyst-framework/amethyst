require "json"
require "./structured_logging"

module Amethyst
  module Observability
    # Tracing span status
    enum SpanStatus
      OK
      CANCELLED
      UNKNOWN
      INVALID_ARGUMENT
      DEADLINE_EXCEEDED
      NOT_FOUND
      ALREADY_EXISTS
      PERMISSION_DENIED
      RESOURCE_EXHAUSTED
      FAILED_PRECONDITION
      ABORTED
      OUT_OF_RANGE
      UNIMPLEMENTED
      INTERNAL
      UNAVAILABLE
      DATA_LOSS
      UNAUTHENTICATED
    end
    
    # Span kind
    enum SpanKind
      INTERNAL
      SERVER
      CLIENT
      PRODUCER
      CONSUMER
    end
    
    # Trace context for propagation
    struct TraceContext
      property trace_id : String
      property span_id : String
      property parent_span_id : String?
      property trace_flags : UInt8
      property trace_state : String?
      property baggage : Hash(String, String)?
      
      def initialize(@trace_id : String, @span_id : String, @parent_span_id : String? = nil,
                     @trace_flags : UInt8 = 0_u8, @trace_state : String? = nil)
        @baggage = Hash(String, String).new
      end
      
      def self.generate : TraceContext
        new(
          trace_id: Random::Secure.hex(16),
          span_id: Random::Secure.hex(8)
        )
      end
      
      def child_context : TraceContext
        new(
          trace_id: @trace_id,
          span_id: Random::Secure.hex(8),
          parent_span_id: @span_id,
          trace_flags: @trace_flags,
          trace_state: @trace_state
        ).tap do |child|
          child.baggage = @baggage.try(&.dup)
        end
      end
      
      def to_w3c_traceparent : String
        "00-#{@trace_id}-#{@span_id}-#{@trace_flags.to_s(16).rjust(2, '0')}"
      end
      
      def self.from_w3c_traceparent(header : String) : TraceContext?
        parts = header.split("-")
        return nil unless parts.size == 4
        
        version, trace_id, span_id, flags = parts
        return nil unless version == "00"
        return nil unless trace_id.size == 32 && span_id.size == 16
        
        new(
          trace_id: trace_id,
          span_id: span_id,
          trace_flags: flags.to_u8?(16) || 0_u8
        )
      rescue
        nil
      end
      
      def to_w3c_tracestate : String?
        @trace_state
      end
      
      def self.from_w3c_tracestate(header : String) : String?
        header.empty? ? nil : header
      end
    end
    
    # Distributed tracing span
    class Span
      getter :span_id
      getter :trace_id
      getter :parent_span_id
      getter :operation_name
      getter :kind
      getter :start_time
      property :end_time
      property :status
      property :status_message
      getter :tags
      getter :logs
      getter :process_tags
      
      @span_id : String
      @trace_id : String
      @parent_span_id : String?
      @operation_name : String
      @kind : SpanKind
      @start_time : Time
      @end_time : Time?
      @status : SpanStatus
      @status_message : String?
      @tags : Hash(String, String | Int64 | Float64 | Bool)
      @logs : Array(SpanLog)
      @process_tags : Hash(String, String)
      
      struct SpanLog
        include JSON::Serializable
        
        property timestamp : String
        property level : String
        property message : String
        property fields : Hash(String, String)?
        
        def initialize(@timestamp : String, @level : String, @message : String, @fields : Hash(String, String)? = nil)
        end
      end
      
      def initialize(@operation_name : String, context : TraceContext, @kind : SpanKind = SpanKind::INTERNAL)
        @span_id = context.span_id
        @trace_id = context.trace_id
        @parent_span_id = context.parent_span_id
        @start_time = Time.utc
        @end_time = nil
        @status = SpanStatus::OK
        @status_message = nil
        @tags = Hash(String, String | Int64 | Float64 | Bool).new
        @logs = Array(SpanLog).new
        @process_tags = Hash(String, String).new
        
        # Set default tags
        set_tag("span.kind", @kind.to_s.downcase)
        set_tag("component", LogContext.get("component") || "amethyst")
        set_tag("service.name", LogContext.get("service") || "unknown")
        set_tag("service.version", LogContext.get("version") || "unknown")
      end
      
      def set_tag(key : String, value : String | Int64 | Float64 | Bool)
        @tags[key] = value
      end
      
      def set_error(error : Exception)
        @status = SpanStatus::INTERNAL
        @status_message = error.message
        set_tag("error", true)
        set_tag("error.object", error.class.name)
        set_tag("error.message", error.message || "Unknown error")
        
        log("error", error.message || "Unknown error", {
          "error.class" => error.class.name,
          "stack_trace" => error.backtrace?.try(&.join("\n")) || ""
        })
      end
      
      def log(level : String, message : String, fields : Hash(String, String)? = nil)
        @logs << SpanLog.new(Time.utc.to_rfc3339, level, message, fields)
      end
      
      def finish(status : SpanStatus = SpanStatus::OK, message : String? = nil)
        @end_time = Time.utc
        @status = status
        @status_message = message
        
        # Report span to tracer
        TracingManager.current_tracer.try(&.report_span(self))
      end
      
      def duration : Time::Span?
        end_time = @end_time
        return nil unless end_time
        end_time - @start_time
      end
      
      def to_jaeger_json : String
        {
          traceID: @trace_id,
          spanID: @span_id,
          parentSpanID: @parent_span_id,
          operationName: @operation_name,
          startTime: (@start_time.to_unix_f * 1_000_000).to_i64,
          duration: duration.try(&.total_microseconds.to_i64) || 0,
          tags: @tags.map { |k, v| {key: k, value: v.to_s, type: type_for_value(v)} },
          logs: @logs.map { |log| 
            {
              timestamp: (Time.parse_rfc3339(log.timestamp).to_unix_f * 1_000_000).to_i64,
              fields: [
                {key: "level", value: log.level},
                {key: "message", value: log.message}
              ] + (log.fields.try(&.map { |k, v| {key: k, value: v} }) || [] of NamedTuple(key: String, value: String))
            }
          },
          process: {
            serviceName: LogContext.get("service") || "amethyst",
            tags: @process_tags.map { |k, v| {key: k, value: v, type: "string"} }
          },
          warnings: [] of String
        }.to_json
      end
      
      private def type_for_value(value : String | Int64 | Float64 | Bool) : String
        case value
        when String then "string"
        when Int64 then "number"
        when Float64 then "number"
        when Bool then "bool"
        else "string"
        end
      end
    end
    
    # Tracer interface
    abstract class Tracer
      abstract def start_span(operation_name : String, parent : Span? = nil, kind : SpanKind = SpanKind::INTERNAL) : Span
      abstract def report_span(span : Span)
      abstract def close
      abstract def flush
    end
    
    # In-memory tracer for development
    class InMemoryTracer < Tracer
      @spans : Array(Span)
      @mutex : Mutex
      
      def initialize
        @spans = Array(Span).new
        @mutex = Mutex.new
      end
      
      def start_span(operation_name : String, parent : Span? = nil, kind : SpanKind = SpanKind::INTERNAL) : Span
        context = if parent
          TraceContext.new(parent.trace_id, Random::Secure.hex(8), parent.span_id)
        else
          TraceContext.generate
        end
        
        span = Span.new(operation_name, context, kind)
        
        # Set trace context in logging
        LogContext.set("trace_id", span.trace_id)
        LogContext.set("span_id", span.span_id)
        
        span
      end
      
      def report_span(span : Span)
        @mutex.synchronize do
          @spans << span
        end
      end
      
      def close
        # Nothing to close for in-memory tracer
      end
      
      def flush
        # Nothing to flush for in-memory tracer
      end
      
      def spans : Array(Span)
        @mutex.synchronize { @spans.dup }
      end
      
      def clear
        @mutex.synchronize { @spans.clear }
      end
    end
    
    # Jaeger tracer (HTTP collector)
    class JaegerTracer < Tracer
      @service_name : String
      @endpoint : String
      @batch_size : Int32
      @flush_interval : Time::Span
      @spans : Array(Span)
      @mutex : Mutex
      @client : ::HTTP::Client
      @flush_fiber : Fiber?
      
      def initialize(@service_name : String, @endpoint : String = "http://localhost:14268/api/traces",
                     @batch_size : Int32 = 100, @flush_interval : Time::Span = 10.seconds)
        @spans = Array(Span).new
        @mutex = Mutex.new
        @client = ::HTTP::Client.new(URI.parse(@endpoint))
        
        start_flush_loop
      end
      
      def start_span(operation_name : String, parent : Span? = nil, kind : SpanKind = SpanKind::INTERNAL) : Span
        context = if parent
          TraceContext.new(parent.trace_id, Random::Secure.hex(8), parent.span_id)
        else
          TraceContext.generate
        end
        
        span = Span.new(operation_name, context, kind)
        span.set_tag("service.name", @service_name)
        
        # Set trace context in logging
        LogContext.set("trace_id", span.trace_id)
        LogContext.set("span_id", span.span_id)
        
        span
      end
      
      def report_span(span : Span)
        @mutex.synchronize do
          @spans << span
          
          if @spans.size >= @batch_size
            flush_spans
          end
        end
      end
      
      def close
        flush
        @client.close
        # Fiber cleanup is handled by the runtime
        # @flush_fiber.try(&.terminate)
      end
      
      def flush
        @mutex.synchronize do
          flush_spans
        end
      end
      
      private def flush_spans
        return if @spans.empty?
        
        batch = @spans.dup
        @spans.clear
        
        spawn do
          send_spans(batch)
        end
      end
      
      private def send_spans(spans : Array(Span))
        traces = group_spans_by_trace(spans)
        
        jaeger_batch = {
          spans: spans.map { |span| JSON.parse(span.to_jaeger_json) },
          process: {
            serviceName: @service_name,
            tags: [] of Hash(String, String)
          }
        }
        
        begin
          response = @client.post(@endpoint, 
            headers: ::HTTP::Headers{"Content-Type" => "application/json"},
            body: jaeger_batch.to_json
          )
          
          unless response.success?
            Observability.logger?.try(&.error("Failed to send spans to Jaeger",
              status_code: response.status_code,
              response_body: response.body
            ))
          end
        rescue ex
          Observability.logger?.try(&.error("Error sending spans to Jaeger", error: ex))
        end
      end
      
      private def group_spans_by_trace(spans : Array(Span)) : Hash(String, Array(Span))
        spans.group_by(&.trace_id)
      end
      
      private def start_flush_loop
        @flush_fiber = spawn do
          loop do
            sleep @flush_interval
            flush
          end
        end
      end
    end
    
    # OpenTelemetry OTLP exporter
    class OTLPTracer < Tracer
      @service_name : String
      @endpoint : String
      @headers : ::HTTP::Headers
      @batch_size : Int32
      @flush_interval : Time::Span
      @spans : Array(Span)
      @mutex : Mutex
      @client : ::HTTP::Client
      @flush_fiber : Fiber?
      
      def initialize(@service_name : String, @endpoint : String = "http://localhost:4318/v1/traces",
                     headers : Hash(String, String) = {} of String => String,
                     @batch_size : Int32 = 100, @flush_interval : Time::Span = 10.seconds)
        @headers = ::HTTP::Headers.new
        headers.each { |k, v| @headers[k] = v }
        @headers["Content-Type"] = "application/json"
        
        @spans = Array(Span).new
        @mutex = Mutex.new
        @client = ::HTTP::Client.new(URI.parse(@endpoint))
        
        start_flush_loop
      end
      
      def start_span(operation_name : String, parent : Span? = nil, kind : SpanKind = SpanKind::INTERNAL) : Span
        context = if parent
          TraceContext.new(parent.trace_id, Random::Secure.hex(8), parent.span_id)
        else
          TraceContext.generate
        end
        
        span = Span.new(operation_name, context, kind)
        span.set_tag("service.name", @service_name)
        
        # Set trace context in logging
        LogContext.set("trace_id", span.trace_id)
        LogContext.set("span_id", span.span_id)
        
        span
      end
      
      def report_span(span : Span)
        @mutex.synchronize do
          @spans << span
          
          if @spans.size >= @batch_size
            flush_spans
          end
        end
      end
      
      def close
        flush
        @client.close
        # Fiber cleanup is handled by the runtime
        # @flush_fiber.try(&.terminate)
      end
      
      def flush
        @mutex.synchronize do
          flush_spans
        end
      end
      
      private def flush_spans
        return if @spans.empty?
        
        batch = @spans.dup
        @spans.clear
        
        spawn do
          send_spans(batch)
        end
      end
      
      private def send_spans(spans : Array(Span))
        otlp_payload = {
          resourceSpans: [{
            resource: {
              attributes: [
                {key: "service.name", value: {stringValue: @service_name}},
                {key: "service.version", value: {stringValue: LogContext.get("version") || "unknown"}}
              ]
            },
            instrumentationLibrarySpans: [{
              instrumentationLibrary: {
                name: "amethyst-tracing",
                version: "1.0.0"
              },
              spans: spans.map { |span| span_to_otlp(span) }
            }]
          }]
        }
        
        begin
          response = @client.post(@endpoint, 
            headers: @headers,
            body: otlp_payload.to_json
          )
          
          unless response.success?
            Observability.logger?.try(&.error("Failed to send spans to OTLP collector",
              status_code: response.status_code,
              response_body: response.body
            ))
          end
        rescue ex
          Observability.logger?.try(&.error("Error sending spans to OTLP collector", error: ex))
        end
      end
      
      private def span_to_otlp(span : Span)
        {
          traceId: span.trace_id,
          spanId: span.span_id,
          parentSpanId: span.parent_span_id,
          name: span.operation_name,
          kind: otlp_span_kind(span.kind),
          startTimeUnixNano: (span.start_time.to_unix_f * 1_000_000_000).to_u64,
          endTimeUnixNano: span.end_time.try { |t| (t.to_unix_f * 1_000_000_000).to_u64 } || 0_u64,
          status: {
            code: otlp_status_code(span.status),
            message: span.status_message || ""
          },
          attributes: span.tags.map { |k, v| 
            {
              key: k,
              value: case v
                     when String then {stringValue: v}
                     when Int64 then {intValue: v}
                     when Float64 then {doubleValue: v}
                     when Bool then {boolValue: v}
                     else {stringValue: v.to_s}
                     end
            }
          },
          events: span.logs.map { |log|
            {
              timeUnixNano: (Time.parse_rfc3339(log.timestamp).to_unix_f * 1_000_000_000).to_u64,
              name: log.message,
              attributes: (log.fields || {} of String => String).map { |k, v|
                {key: k, value: {stringValue: v}}
              }
            }
          }
        }
      end
      
      private def otlp_span_kind(kind : SpanKind) : Int32
        case kind
        when .internal? then 1
        when .server? then 2
        when .client? then 3
        when .producer? then 4
        when .consumer? then 5
        else 0
        end
      end
      
      private def otlp_status_code(status : SpanStatus) : Int32
        case status
        when .ok? then 1
        when .cancelled? then 2
        else 3 # ERROR
        end
      end
      
      private def start_flush_loop
        @flush_fiber = spawn do
          loop do
            sleep @flush_interval
            flush
          end
        end
      end
    end
    
    # Tracing manager
    class TracingManager
      @@current_tracer : Tracer?
      @@current_span : Span?
      @@span_stack = [] of Span
      @@mutex = Mutex.new
      
      def self.configure(tracer : Tracer)
        @@current_tracer = tracer
      end
      
      def self.current_tracer : Tracer?
        @@current_tracer
      end
      
      def self.start_span(operation_name : String, parent : Span? = nil, kind : SpanKind = SpanKind::INTERNAL, &block : Span ->)
        tracer = @@current_tracer
        return yield DummySpan.new unless tracer
        
        span = tracer.start_span(operation_name, parent || @@current_span, kind)
        
        @@mutex.synchronize do
          @@span_stack << @@current_span if @@current_span
          @@current_span = span
        end
        
        begin
          result = yield span
          span.finish
          result
        rescue ex
          span.set_error(ex)
          span.finish(SpanStatus::INTERNAL, ex.message)
          raise ex
        ensure
          @@mutex.synchronize do
            @@current_span = @@span_stack.pop?
          end
        end
      end
      
      def self.current_span : Span?
        @@current_span
      end
      
      def self.close
        @@current_tracer.try(&.close)
      end
      
      def self.flush
        @@current_tracer.try(&.flush)
      end
      
      # Dummy span for when tracing is disabled
      private class DummySpan
        def initialize
        end
        
        def set_tag(key : String, value : String | Int64 | Float64 | Bool)
        end
        
        def set_error(error : Exception)
        end
        
        def log(level : String, message : String, fields : Hash(String, String)? = nil)
        end
        
        def finish(status : SpanStatus = SpanStatus::OK, message : String? = nil)
        end
        
        def span_id : String
          "dummy"
        end
        
        def trace_id : String
          "dummy"
        end
      end
    end
    
    # Tracing middleware
    class TracingMiddleware < Middleware::Base
      @operation_name : String
      @tag_headers : Array(String)
      @logger : StructuredLogger?
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @operation_name = "http_request"
        @tag_headers = ["User-Agent", "Content-Type"]
        @logger = nil
      end
      
      def call(request) : Http::Response
        # Extract trace context from headers
        trace_context = extract_trace_context(request)
        
        TracingManager.start_span(@operation_name, kind: SpanKind::SERVER) do |span|
          # Set span tags
          span.set_tag("http.method", request.method)
          span.set_tag("http.url", request.path)
          span.set_tag("http.scheme", extract_scheme(request))
          span.set_tag("http.host", request.headers["Host"]? || "unknown")
          span.set_tag("http.user_agent", request.headers["User-Agent"]? || "unknown")
          span.set_tag("http.remote_addr", extract_remote_ip(request))
          
          # Add custom headers as tags
          @tag_headers.each do |header|
            if value = request.headers[header]?
              span.set_tag("http.header.#{header.downcase}", value)
            end
          end
          
          # Add trace context to response headers
          response = @app.call(request)
          
          # Set response tags
          span.set_tag("http.status_code", response.status_code)
          span.set_tag("http.response_size", response.body.try(&.bytesize) || 0)
          
          # Set status based on response code
          if response.status_code >= 400
            status = response.status_code >= 500 ? SpanStatus::INTERNAL : SpanStatus::INVALID_ARGUMENT
            span.finish(status, "HTTP #{response.status_code}")
          end
          
          # Add trace headers to response
          add_trace_headers(response, span)
          
          response
        end
      end
      
      private def extract_trace_context(request : Http::Request) : TraceContext?
        traceparent = request.headers["traceparent"]?
        return nil unless traceparent
        
        TraceContext.from_w3c_traceparent(traceparent).tap do |context|
          if context && (tracestate = request.headers["tracestate"]?)
            context.trace_state = TraceContext.from_w3c_tracestate(tracestate)
          end
        end
      end
      
      private def extract_scheme(request : Http::Request) : String
        request.headers["X-Forwarded-Proto"]? || 
        request.headers["X-Forwarded-Scheme"]? || 
        "http"
      end
      
      private def extract_remote_ip(request : Http::Request) : String
        request.headers["X-Forwarded-For"]?.try(&.split(",").first.strip) ||
        request.headers["X-Real-IP"]? ||
        "unknown"
      end
      
      private def add_trace_headers(response : Http::Response, span : Span)
        # Add trace ID to response for correlation
        response.headers["X-Trace-ID"] = span.trace_id
        response.headers["X-Span-ID"] = span.span_id
      end
    end
  end
end