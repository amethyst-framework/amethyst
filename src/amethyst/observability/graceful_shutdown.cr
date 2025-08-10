require "signal"
require "./structured_logging"
require "./health_metrics"

module Amethyst
  module Observability
    # Shutdown hook interface
    abstract class ShutdownHook
      abstract def execute(timeout : Time::Span) : Bool
      abstract def name : String
      
      def priority : Int32
        100  # Default priority, lower numbers execute first
      end
      
      def timeout : Time::Span
        30.seconds  # Default timeout for this hook
      end
    end
    
    # Database connection shutdown hook
    class DatabaseShutdownHook < ShutdownHook
      @db_connections : Array(DB::Database)?
      
      def initialize(@db_connections : Array(DB::Database)? = nil)
      end
      
      def name : String
        "database"
      end
      
      def priority : Int32
        10  # Close database connections early
      end
      
      def execute(timeout : Time::Span) : Bool
        return true unless connections = @db_connections
        
        connections.each do |db|
          begin
            db.close
          rescue ex
            Observability.logger?.try(&.error("Failed to close database connection", error: ex))
          end
        end
        
        true
      end
    end
    
    # Cache shutdown hook
    class CacheShutdownHook < ShutdownHook
      @cache_stores : Array(Middleware::CacheStore)?
      
      def initialize(@cache_stores : Array(Middleware::CacheStore)? = nil)
      end
      
      def name : String
        "cache"
      end
      
      def priority : Int32
        20
      end
      
      def execute(timeout : Time::Span) : Bool
        return true unless stores = @cache_stores
        
        stores.each do |store|
          begin
            # Flush any pending cache operations
            store.cleanup_expired
          rescue ex
            Observability.logger?.try(&.error("Failed to cleanup cache store", error: ex))
          end
        end
        
        true
      end
    end
    
    # WebSocket connections shutdown hook
    class WebSocketShutdownHook < ShutdownHook
      def name : String
        "websocket"
      end
      
      def priority : Int32
        30
      end
      
      def execute(timeout : Time::Span) : Bool
        begin
          # Gracefully close all WebSocket connections
          manager = WebSocket::ConnectionManager.instance
          stats = manager.stats
          active_connections = stats[:active_connections]?.try(&.as(Int32)) || 0
          
          if active_connections > 0
            Observability.logger?.try(&.info("Closing #{active_connections} WebSocket connections"))
            
            # Send close message to all connections
            manager.broadcast_to_all({
              "type" => "server_shutdown",
              "message" => "Server is shutting down gracefully",
              "timestamp" => Time.utc.to_rfc3339
            })
            
            # Give connections time to close gracefully
            sleep Math.min(timeout.total_seconds, 5.0).seconds
            
            # Cleanup any remaining connections
            manager.cleanup_closed_connections
          end
          
          true
        rescue ex
          Observability.logger?.try(&.error("Failed to shutdown WebSocket connections", error: ex))
          false
        end
      end
    end
    
    # SSE connections shutdown hook
    class SSEShutdownHook < ShutdownHook
      def name : String
        "sse"
      end
      
      def priority : Int32
        35
      end
      
      def execute(timeout : Time::Span) : Bool
        begin
          # Gracefully close all SSE connections
          manager = SSE::ConnectionManager.instance
          stats = manager.stats
          active_connections = stats[:active_connections]?.try(&.as(Int32)) || 0
          
          if active_connections > 0
            Observability.logger?.try(&.info("Closing #{active_connections} SSE connections"))
            
            # Send final event to all connections
            manager.broadcast_to_all({
              "message" => "Server is shutting down gracefully",
              "timestamp" => Time.utc.to_rfc3339
            }, "server_shutdown")
            
            # Give connections time to receive the message
            sleep 2.seconds
            
            # Cleanup connections
            manager.cleanup_closed_connections
          end
          
          true
        rescue ex
          Observability.logger?.try(&.error("Failed to shutdown SSE connections", error: ex))
          false
        end
      end
    end
    
    # Request completion shutdown hook
    class RequestCompletionHook < ShutdownHook
      @active_requests : Atomic(Int32)
      @max_wait_time : Time::Span
      
      def initialize(@max_wait_time : Time::Span = 30.seconds)
        @active_requests = Atomic(Int32).new(0)
      end
      
      def name : String
        "request_completion"
      end
      
      def priority : Int32
        40  # Wait for requests before final cleanup
      end
      
      def timeout : Time::Span
        @max_wait_time
      end
      
      def increment_active_requests
        @active_requests.add(1)
      end
      
      def decrement_active_requests
        @active_requests.sub(1)
      end
      
      def active_requests : Int32
        @active_requests.get
      end
      
      def execute(timeout : Time::Span) : Bool
        active = @active_requests.get
        
        if active > 0
          Observability.logger?.try(&.info("Waiting for #{active} active requests to complete"))
          
          start_time = Time.monotonic
          check_interval = 1.second
          
          while @active_requests.get > 0 && (Time.monotonic - start_time) < timeout
            sleep check_interval
            remaining = @active_requests.get
            
            if remaining > 0
              elapsed = (Time.monotonic - start_time).total_seconds
              Observability.logger?.try(&.debug("Still waiting for #{remaining} requests (#{elapsed.round(1)}s elapsed)"))
            end
          end
          
          final_active = @active_requests.get
          if final_active > 0
            Observability.logger?.try(&.warn("Shutdown timeout reached, #{final_active} requests still active"))
            return false
          end
        end
        
        Observability.logger?.try(&.info("All requests completed"))
        true
      end
    end
    
    # Logging and tracing shutdown hook
    class LoggingShutdownHook < ShutdownHook
      def name : String
        "logging"
      end
      
      def priority : Int32
        90  # Close logging near the end
      end
      
      def execute(timeout : Time::Span) : Bool
        begin
          # Flush and close logger
          Observability.logger?.try do |logger|
            logger.flush
            logger.close
          end
          
          # Flush and close tracer
          TracingManager.flush
          TracingManager.close
          
          true
        rescue ex
          STDERR.puts "Failed to shutdown logging: #{ex.message}"
          false
        end
      end
    end
    
    # Metrics shutdown hook
    class MetricsShutdownHook < ShutdownHook
      def name : String
        "metrics"
      end
      
      def priority : Int32
        85
      end
      
      def execute(timeout : Time::Span) : Bool
        begin
          # Record final metrics
          Observability.metrics?.try do |metrics|
            metrics.gauge("app_shutdown_timestamp", Time.utc.to_unix.to_f64)
          end
          
          true
        rescue ex
          Observability.logger?.try(&.error("Failed to record shutdown metrics", error: ex))
          false
        end
      end
    end
    
    # Graceful shutdown manager
    class GracefulShutdownManager
      @hooks : Array(ShutdownHook)
      @shutdown_timeout : Time::Span
      @signal_handlers : Hash(Signal, Proc(Signal, Nil))
      @shutdown_in_progress : Bool
      @logger : StructuredLogger?
      @mutex : Mutex
      @request_completion_hook : RequestCompletionHook?
      
      def initialize(@shutdown_timeout : Time::Span = 30.seconds, @logger : StructuredLogger? = nil)
        @hooks = Array(ShutdownHook).new
        @signal_handlers = Hash(Signal, Proc(Signal, Nil)).new
        @shutdown_in_progress = false
        @mutex = Mutex.new
        
        # Add default shutdown hooks
        add_default_hooks
        setup_signal_handlers
      end
      
      def add_hook(hook : ShutdownHook)
        @mutex.synchronize do
          @hooks << hook
          @hooks.sort_by!(&.priority)
        end
      end
      
      def remove_hook(name : String)
        @mutex.synchronize do
          @hooks.reject! { |hook| hook.name == name }
        end
      end
      
      def add_database_connections(connections : Array(DB::Database))
        add_hook(DatabaseShutdownHook.new(connections))
      end
      
      def add_cache_stores(stores : Array(Middleware::CacheStore))
        add_hook(CacheShutdownHook.new(stores))
      end
      
      def increment_active_requests
        @request_completion_hook.try(&.increment_active_requests)
      end
      
      def decrement_active_requests
        @request_completion_hook.try(&.decrement_active_requests)
      end
      
      def active_requests : Int32
        @request_completion_hook.try(&.active_requests) || 0
      end
      
      def shutdown(reason : String = "Manual shutdown") : Bool
        @mutex.synchronize do
          return false if @shutdown_in_progress
          @shutdown_in_progress = true
        end
        
        start_time = Time.monotonic
        
        @logger.try(&.info("Graceful shutdown initiated", reason: reason, timeout_seconds: @shutdown_timeout.total_seconds))
        
        success = true
        
        @hooks.each do |hook|
          hook_start = Time.monotonic
          remaining_timeout = @shutdown_timeout - (hook_start - start_time)
          
          if remaining_timeout <= Time::Span.zero
            @logger.try(&.error("Shutdown timeout exceeded before hook", hook: hook.name))
            success = false
            break
          end
          
          hook_timeout = [hook.timeout, remaining_timeout].min
          
          @logger.try(&.debug("Executing shutdown hook", 
            hook: hook.name, 
            priority: hook.priority,
            timeout_seconds: hook_timeout.total_seconds
          ))
          
          begin
            hook_success = hook.execute(hook_timeout)
            duration = (Time.monotonic - hook_start).total_milliseconds
            
            if hook_success
              @logger.try(&.info("Shutdown hook completed successfully", 
                hook: hook.name, 
                duration_ms: duration
              ))
            else
              @logger.try(&.error("Shutdown hook failed", 
                hook: hook.name, 
                duration_ms: duration
              ))
              success = false
            end
          rescue ex
            duration = (Time.monotonic - hook_start).total_milliseconds
            @logger.try(&.error("Shutdown hook raised exception", 
              hook: hook.name, 
              duration_ms: duration,
              error: ex
            ))
            success = false
          end
        end
        
        total_duration = (Time.monotonic - start_time).total_seconds
        
        if success
          @logger.try(&.info("Graceful shutdown completed successfully", 
            total_duration_seconds: total_duration
          ))
        else
          @logger.try(&.error("Graceful shutdown completed with errors", 
            total_duration_seconds: total_duration
          ))
        end
        
        success
      end
      
      def shutdown_on_signal(signal : Signal)
        @signal_handlers[signal] = ->(sig : Signal) {
          @logger.try(&.info("Received shutdown signal", signal: sig.to_s))
          
          spawn do
            success = shutdown("Signal #{sig}")
            exit_code = success ? 0 : 1
            
            @logger.try(&.info("Exiting process", exit_code: exit_code))
            exit(exit_code)
          end
        }
        
        signal.trap(&@signal_handlers[signal])
      end
      
      def status : Hash(String, JSON::Any)
        {
          "shutdown_in_progress" => JSON::Any.new(@shutdown_in_progress),
          "active_requests" => JSON::Any.new(active_requests),
          "hooks_count" => JSON::Any.new(@hooks.size),
          "timeout_seconds" => JSON::Any.new(@shutdown_timeout.total_seconds),
          "registered_hooks" => JSON::Any.new(@hooks.map { |hook| JSON::Any.new(hook.name) })
        }
      end
      
      private def add_default_hooks
        # Add request completion hook and keep reference for request tracking
        @request_completion_hook = RequestCompletionHook.new(@shutdown_timeout)
        add_hook(@request_completion_hook.not_nil!)
        
        # Add other default hooks
        add_hook(WebSocketShutdownHook.new)
        add_hook(SSEShutdownHook.new)
        add_hook(MetricsShutdownHook.new)
        add_hook(LoggingShutdownHook.new)
      end
      
      private def setup_signal_handlers
        # Setup default signal handlers for graceful shutdown
        shutdown_on_signal(Signal::TERM)
        shutdown_on_signal(Signal::INT)
        
        # Handle SIGUSR1 for status reporting
        Signal::USR1.trap do
          @logger.try(&.info("Shutdown manager status: #{status.to_json}"))
        end
      end
    end
    
    # Request tracking middleware
    class RequestTrackingMiddleware < Middleware::Base
      @shutdown_manager : GracefulShutdownManager
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @shutdown_manager = GracefulShutdownManager.new
      end
      
      def call(request) : Http::Response
        # Check if shutdown is in progress
        if @shutdown_manager.status["shutdown_in_progress"].as_bool
          response = Http::Response.new(503, "Service Unavailable")
          response.headers["Content-Type"] = "application/json"
          response.headers["Retry-After"] = "60"  # Suggest retry after 60 seconds
          response.body = {
            error: "Server is shutting down",
            message: "The server is currently shutting down gracefully. Please try again later.",
            timestamp: Time.utc.to_rfc3339
          }.to_json
          return response
        end
        
        # Track active request
        @shutdown_manager.increment_active_requests
        
        begin
          @app.call(request)
        ensure
          @shutdown_manager.decrement_active_requests
        end
      end
    end
    
    # Global shutdown manager instance
    @@shutdown_manager : GracefulShutdownManager?
    
    def self.configure_shutdown(timeout : Time::Span = 30.seconds, logger : StructuredLogger? = nil)
      @@shutdown_manager = GracefulShutdownManager.new(timeout, logger)
    end
    
    def self.shutdown_manager : GracefulShutdownManager
      @@shutdown_manager || raise "Shutdown manager not configured. Call Observability.configure_shutdown first."
    end
    
    def self.shutdown_manager? : GracefulShutdownManager?
      @@shutdown_manager
    end
    
    def self.shutdown(reason : String = "Manual shutdown") : Bool
      shutdown_manager.shutdown(reason)
    end
    
    # Health check for shutdown readiness
    class ShutdownReadinessCheck < HealthCheck
      @shutdown_manager : GracefulShutdownManager
      
      def initialize(@shutdown_manager : GracefulShutdownManager)
      end
      
      def name : String
        "shutdown_readiness"
      end
      
      def critical? : Bool
        false  # Not critical for normal operation
      end
      
      def check : HealthCheckResult
        measure_time do
          status = @shutdown_manager.status
          shutdown_in_progress = status["shutdown_in_progress"].as_bool
          active_requests = status["active_requests"].as_i
          
          if shutdown_in_progress
            HealthCheckResult.new(name, "DOWN", 0.0, "Shutdown in progress", {
              "active_requests" => JSON::Any.new(active_requests),
              "shutdown_in_progress" => JSON::Any.new(true)
            })
          else
            HealthCheckResult.new(name, "UP", 0.0, "Ready for shutdown", {
              "active_requests" => JSON::Any.new(active_requests),
              "shutdown_in_progress" => JSON::Any.new(false),
              "hooks_count" => status["hooks_count"]
            })
          end
        end
      end
    end
  end
end