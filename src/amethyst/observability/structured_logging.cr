require "json"
require "colorize"

module Amethyst
  module Observability
    # Log levels
    enum LogLevel
      TRACE
      DEBUG
      INFO
      WARN
      ERROR
      FATAL
      
      def to_i
        case self
        when .trace? then 0
        when .debug? then 1
        when .info? then 2
        when .warn? then 3
        when .error? then 4
        when .fatal? then 5
        else 2
        end
      end
      
      def to_s(io : IO) : Nil
        io << case self
              when .trace? then "TRACE"
              when .debug? then "DEBUG"
              when .info? then "INFO"
              when .warn? then "WARN"
              when .error? then "ERROR"
              when .fatal? then "FATAL"
              else "INFO"
              end
      end
      
      def color
        case self
        when .trace? then :dark_gray
        when .debug? then :cyan
        when .info? then :green
        when .warn? then :yellow
        when .error? then :red
        when .fatal? then :magenta
        else :white
        end
      end
    end
    
    # Log entry structure
    struct LogEntry
      include JSON::Serializable
      
      property timestamp : String
      property level : String
      property message : String
      property correlation_id : String?
      property trace_id : String?
      property span_id : String?
      property service : String
      property version : String?
      property environment : String
      property component : String?
      property user_id : String?
      property request_id : String?
      property method : String?
      property path : String?
      property status_code : Int32?
      property duration_ms : Float64?
      property error : String?
      property stack_trace : String?
      property metadata : Hash(String, JSON::Any)?
      property tags : Array(String)?
      
      def initialize(@level : String, @message : String, @service : String, @environment : String)
        @timestamp = Time.utc.to_rfc3339
        @correlation_id = LogContext.current_correlation_id
        @trace_id = LogContext.current_trace_id
        @span_id = LogContext.current_span_id
        @version = LogContext.current_version
        @component = LogContext.current_component
        @user_id = LogContext.current_user_id
        @request_id = LogContext.current_request_id
      end
    end
    
    # Log context for correlation IDs and tracing
    class LogContext
      @@fiber_storage = {} of Fiber => Hash(String, String)
      @@global_context = Hash(String, String).new
      @@mutex = Mutex.new
      
      def self.with_context(context : Hash(String, String), &block)
        fiber = Fiber.current
        
        @@mutex.synchronize do
          @@fiber_storage[fiber] = context
        end
        
        begin
          yield
        ensure
          @@mutex.synchronize do
            @@fiber_storage.delete(fiber)
          end
        end
      end
      
      def self.set(key : String, value : String)
        fiber = Fiber.current
        
        @@mutex.synchronize do
          @@fiber_storage[fiber] ||= Hash(String, String).new
          @@fiber_storage[fiber][key] = value
        end
      end
      
      def self.get(key : String) : String?
        fiber = Fiber.current
        
        @@mutex.synchronize do
          context = @@fiber_storage[fiber]?
          return context[key]? if context
          @@global_context[key]?
        end
      end
      
      def self.set_global(key : String, value : String)
        @@mutex.synchronize do
          @@global_context[key] = value
        end
      end
      
      def self.current_correlation_id : String?
        get("correlation_id")
      end
      
      def self.current_trace_id : String?
        get("trace_id")
      end
      
      def self.current_span_id : String?
        get("span_id")
      end
      
      def self.current_version : String?
        get("version")
      end
      
      def self.current_component : String?
        get("component")
      end
      
      def self.current_user_id : String?
        get("user_id")
      end
      
      def self.current_request_id : String?
        get("request_id")
      end
      
      def self.generate_correlation_id : String
        "cor_#{Random::Secure.hex(8)}"
      end
      
      def self.generate_request_id : String
        "req_#{Random::Secure.hex(12)}"
      end
      
      def self.generate_trace_id : String
        Random::Secure.hex(16)
      end
      
      def self.generate_span_id : String
        Random::Secure.hex(8)
      end
      
      def self.current_context : Hash(String, String)
        fiber = Fiber.current
        
        @@mutex.synchronize do
          context = @@fiber_storage[fiber]? || Hash(String, String).new
          context.merge(@@global_context)
        end
      end
    end
    
    # Log output interface
    abstract class LogOutput
      abstract def write(entry : LogEntry)
      abstract def flush
      abstract def close
    end
    
    # Console output with colors
    class ConsoleOutput < LogOutput
      @io : IO
      @use_colors : Bool
      @use_json : Bool
      
      def initialize(@io : IO = STDOUT, @use_colors : Bool = true, @use_json : Bool = false)
      end
      
      def write(entry : LogEntry)
        if @use_json
          @io.puts entry.to_json
        else
          write_formatted(entry)
        end
      end
      
      def flush
        @io.flush
      end
      
      def close
        # Console output doesn't need closing
      end
      
      private def write_formatted(entry : LogEntry)
        level_text = entry.level.ljust(5)
        
        if @use_colors
          level_color = LogLevel.parse?(entry.level).try(&.color) || :white
          level_text = level_text.colorize(level_color).bold.to_s
        end
        
        parts = [
          entry.timestamp,
          level_text,
          entry.service
        ]
        
        if correlation_id = entry.correlation_id
          parts << "[#{correlation_id}]"
        end
        
        if component = entry.component
          parts << "(#{component})"
        end
        
        parts << entry.message
        
        # Add request info if available
        if entry.method && entry.path
          parts << "#{entry.method} #{entry.path}"
          
          if status = entry.status_code
            status_text = status.to_s
            if @use_colors
              status_color = case status
                            when 200..299 then :green
                            when 300..399 then :yellow
                            when 400..499 then :red
                            when 500..599 then :magenta
                            else :white
                            end
              status_text = status_text.colorize(status_color).to_s
            end
            parts << status_text
          end
          
          if duration = entry.duration_ms
            parts << "#{duration.round(2)}ms"
          end
        end
        
        # Add error info
        if error = entry.error
          parts << "ERROR: #{error}"
        end
        
        @io.puts parts.join(" ")
        
        # Print stack trace if available
        if stack_trace = entry.stack_trace
          @io.puts "Stack trace:"
          @io.puts stack_trace
        end
      end
    end
    
    # JSON file output
    class FileOutput < LogOutput
      @file : File
      @buffer : Array(LogEntry)
      @buffer_size : Int32
      @auto_flush : Bool
      @mutex : Mutex
      
      def initialize(file_path : String, @buffer_size : Int32 = 100, @auto_flush : Bool = true)
        @file = File.open(file_path, "a")
        @buffer = Array(LogEntry).new
        @mutex = Mutex.new
      end
      
      def write(entry : LogEntry)
        @mutex.synchronize do
          @buffer << entry
          
          if @buffer.size >= @buffer_size || @auto_flush
            flush_buffer
          end
        end
      end
      
      def flush
        @mutex.synchronize do
          flush_buffer
          @file.flush
        end
      end
      
      def close
        @mutex.synchronize do
          flush_buffer
          @file.close
        end
      end
      
      private def flush_buffer
        @buffer.each do |entry|
          @file.puts entry.to_json
        end
        @buffer.clear
      end
    end
    
    # Structured logger
    class StructuredLogger
      @outputs : Array(LogOutput)
      @min_level : LogLevel
      @service : String
      @version : String?
      @environment : String
      @default_component : String?
      @include_caller : Bool
      @mutex : Mutex
      
      def initialize(@service : String, @environment : String = "production", 
                     @version : String? = nil, @default_component : String? = nil,
                     @min_level : LogLevel = LogLevel::INFO, @include_caller : Bool = false)
        @outputs = Array(LogOutput).new
        @mutex = Mutex.new
        
        # Set global context
        LogContext.set_global("service", @service)
        LogContext.set_global("environment", @environment)
        LogContext.set_global("version", @version.not_nil!) if @version
        LogContext.set_global("component", @default_component.not_nil!) if @default_component
      end
      
      def add_output(output : LogOutput)
        @mutex.synchronize do
          @outputs << output
        end
      end
      
      def remove_output(output : LogOutput)
        @mutex.synchronize do
          @outputs.delete(output)
        end
      end
      
      def level=(level : LogLevel)
        @min_level = level
      end
      
      def trace(message : String, **metadata)
        log(LogLevel::TRACE, message, **metadata)
      end
      
      def debug(message : String, **metadata)
        log(LogLevel::DEBUG, message, **metadata)
      end
      
      def info(message : String, **metadata)
        log(LogLevel::INFO, message, **metadata)
      end
      
      def warn(message : String, **metadata)
        log(LogLevel::WARN, message, **metadata)
      end
      
      def error(message : String, error : Exception? = nil, **metadata)
        if error
          # Create a new log entry with error information
          entry = create_entry(LogLevel::ERROR, message)
          entry.error = error.message || "Unknown error"
          if !metadata.empty?
            entry.metadata = {} of String => JSON::Any
            metadata.each do |key, value|
              entry.metadata.not_nil![key.to_s] = JSON::Any.new(value)
            end
          end
          write_entry(entry)
        else
          log(LogLevel::ERROR, message, **metadata)
        end
      end
      
      def fatal(message : String, error : Exception? = nil, **metadata)
        if error
          # Create a new log entry with error information
          entry = create_entry(LogLevel::FATAL, message)
          entry.error = error.message || "Unknown error"
          if !metadata.empty?
            entry.metadata = {} of String => JSON::Any
            metadata.each do |key, value|
              entry.metadata.not_nil![key.to_s] = JSON::Any.new(value)
            end
          end
          write_entry(entry)
        else
          log(LogLevel::FATAL, message, **metadata)
        end
      end
      
      def log_request(method : String, path : String, status_code : Int32, 
                     duration_ms : Float64, user_id : String? = nil, **metadata)
        entry = create_entry(LogLevel::INFO, "HTTP Request")
        entry.method = method
        entry.path = path
        entry.status_code = status_code
        entry.duration_ms = duration_ms
        entry.user_id = user_id
        
        if !metadata.empty?
          entry.metadata = metadata.transform_values { |v| JSON::Any.new(v) }
        end
        
        write_entry(entry)
      end
      
      def log_database_query(query : String, duration_ms : Float64, **metadata)
        meta = metadata.to_h
        meta["query"] = JSON::Any.new(query)
        meta["query_duration_ms"] = JSON::Any.new(duration_ms)
        
        log(LogLevel::DEBUG, "Database Query", **meta)
      end
      
      def log_cache_operation(operation : String, key : String, hit : Bool, **metadata)
        meta = metadata.to_h
        meta["cache_operation"] = JSON::Any.new(operation)
        meta["cache_key"] = JSON::Any.new(key)
        meta["cache_hit"] = JSON::Any.new(hit)
        
        log(LogLevel::DEBUG, "Cache Operation", **meta)
      end
      
      def log_external_request(url : String, method : String, status_code : Int32, 
                              duration_ms : Float64, **metadata)
        meta = metadata.to_h
        meta["external_url"] = JSON::Any.new(url)
        meta["external_method"] = JSON::Any.new(method)
        meta["external_status"] = JSON::Any.new(status_code)
        meta["external_duration_ms"] = JSON::Any.new(duration_ms)
        
        log(LogLevel::INFO, "External Request", **meta)
      end
      
      def with_context(**context, &block)
        context_hash = context.transform_values(&.to_s)
        LogContext.with_context(context_hash) do
          yield
        end
      end
      
      def with_correlation_id(correlation_id : String? = nil, &block)
        id = correlation_id || LogContext.generate_correlation_id
        with_context(correlation_id: id) do
          yield id
        end
      end
      
      def with_component(component : String, &block)
        with_context(component: component) do
          yield
        end
      end
      
      def flush
        @mutex.synchronize do
          @outputs.each(&.flush)
        end
      end
      
      def close
        @mutex.synchronize do
          @outputs.each(&.close)
        end
      end
      
      private def log(level : LogLevel, message : String, **metadata)
        return if level.to_i < @min_level.to_i
        
        entry = create_entry(level, message)
        
        if !metadata.empty?
          entry.metadata = {} of String => JSON::Any
          metadata.each do |key, value|
            entry.metadata.not_nil![key.to_s] = JSON::Any.new(value)
          end
        end
        
        write_entry(entry)
      end
      
      private def create_entry(level : LogLevel, message : String) : LogEntry
        entry = LogEntry.new(level.to_s, message, @service, @environment)
        
        if @include_caller
          # Add caller information (simplified)
          caller_info = caller[2]?
          if caller_info
            entry.metadata ||= Hash(String, JSON::Any).new
            entry.metadata.not_nil!["caller"] = JSON::Any.new(caller_info)
          end
        end
        
        entry
      end
      
      private def write_entry(entry : LogEntry)
        @mutex.synchronize do
          @outputs.each do |output|
            begin
              output.write(entry)
            rescue ex
              STDERR.puts "Error writing to log output: #{ex.message}"
            end
          end
        end
      end
    end
    
    # Correlation ID middleware
    class CorrelationMiddleware < Middleware::Base
      @header_name : String
      @generate_if_missing : Bool
      @logger : StructuredLogger?
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @header_name = "X-Correlation-ID"
        @generate_if_missing = true
        @logger = nil
      end
      
      def call(request) : Http::Response
        # Extract or generate correlation ID
        correlation_id = request.headers[@header_name]? || 
                        (@generate_if_missing ? LogContext.generate_correlation_id : nil)
        
        # Generate request ID
        request_id = LogContext.generate_request_id
        
        # Extract user ID if available (from JWT or session)
        user_id = extract_user_id(request)
        
        # Set up log context
        context = {
          "correlation_id" => correlation_id,
          "request_id" => request_id,
          "method" => request.method,
          "path" => request.path,
          "user_agent" => request.headers["User-Agent"]? || "unknown",
          "remote_ip" => extract_remote_ip(request)
        }
        
        context["user_id"] = user_id if user_id
        
        start_time = Time.monotonic
        
        LogContext.with_context(context) do
          # Log request start
          @logger.try(&.info("Request started", 
            method: request.method,
            path: request.path,
            user_id: user_id,
            remote_ip: context["remote_ip"]
          ))
          
          response = @app.call(request)
          
          # Add correlation ID to response
          if correlation_id
            response.headers[@header_name] = correlation_id
          end
          
          # Log request completion
          duration = (Time.monotonic - start_time).total_milliseconds
          
          @logger.try(&.log_request(
            method: request.method,
            path: request.path,
            status_code: response.status_code,
            duration_ms: duration,
            user_id: user_id,
            response_size: response.body.try(&.bytesize) || 0
          ))
          
          response
        end
      end
      
      private def extract_user_id(request : Http::Request) : String?
        # Try to extract user ID from JWT token
        auth_header = request.headers["Authorization"]?
        return nil unless auth_header && auth_header.starts_with?("Bearer ")
        
        # This would integrate with your JWT service
        # For now, return a placeholder
        nil
      end
      
      private def extract_remote_ip(request : Http::Request) : String
        # Try various headers for real IP
        request.headers["X-Forwarded-For"]?.try(&.split(",").first.strip) ||
        request.headers["X-Real-IP"]? ||
        request.headers["CF-Connecting-IP"]? ||
        "unknown"
      end
    end
    
    # Request logging middleware
    class RequestLogger < Middleware::Base
      @logger : StructuredLogger
      @log_request_body : Bool
      @log_response_body : Bool
      @max_body_size : Int32
      @skip_paths : Set(String)
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @logger = StructuredLogger.new("app", "production")
        @log_request_body = false
        @log_response_body = false
        @max_body_size = 1024
        @skip_paths = Set{"/health", "/metrics"}
      end
      
      def call(request) : Http::Response
        return @app.call(request) if @skip_paths.includes?(request.path)
        
        start_time = Time.monotonic
        
        # Log request details
        request_metadata = {
          "headers" => request.headers.to_h.transform_values(&.to_s),
          "query_params" => request.query || "",
          "content_type" => request.headers["Content-Type"]? || "unknown"
        }
        
        if @log_request_body && request.body
          body_content = request.body.to_s
          if body_content.size <= @max_body_size
            request_metadata["request_body"] = body_content
          else
            request_metadata["request_body"] = "#{body_content[0, @max_body_size]}... (truncated)"
          end
        end
        
        @logger.debug("Processing request", **request_metadata)
        
        begin
          response = @app.call(request)
          duration = (Time.monotonic - start_time).total_milliseconds
          
          # Log response details
          response_metadata = {
            "status_code" => response.status_code,
            "duration_ms" => duration,
            "response_headers" => response.headers.to_h.transform_values(&.to_s)
          }
          
          if @log_response_body && response.body
            body_content = response.body.to_s
            if body_content.size <= @max_body_size
              response_metadata["response_body"] = body_content
            else
              response_metadata["response_body"] = "#{body_content[0, @max_body_size]}... (truncated)"
            end
          end
          
          level = response.status_code >= 400 ? LogLevel::WARN : LogLevel::INFO
          @logger.log(level, "Request completed", **response_metadata)
          
          response
        rescue ex
          duration = (Time.monotonic - start_time).total_milliseconds
          
          @logger.error("Request failed", 
            error: ex,
            duration_ms: duration,
            error_class: ex.class.name,
            stack_trace: ex.backtrace?.try(&.join("\n"))
          )
          
          raise ex
        end
      end
    end
    
    # Global logger instance
    @@logger : StructuredLogger?
    
    def self.configure_logger(service : String, environment : String = "production", **options)
      @@logger = StructuredLogger.new(service, environment, **options)
      @@logger
    end
    
    def self.logger : StructuredLogger
      @@logger || raise "Logger not configured. Call Observability.configure_logger first."
    end
    
    def self.logger? : StructuredLogger?
      @@logger
    end
  end
end