require "../security/secure_app"
require "./structured_logging"
require "./distributed_tracing"
require "./health_metrics"
require "./graceful_shutdown"

module Amethyst
  module Base
    class ObservableApp < SecureApp
      @logger : Observability::StructuredLogger
      @tracer : Observability::Tracer?
      @health_manager : Observability::HealthCheckManager
      @metrics_collector : Observability::MetricsCollector
      @shutdown_manager : Observability::GracefulShutdownManager
      @observability_config : Observability::ObservabilityConfig
      
      def initialize(app_path, app_type={{@type.name.stringify}},
                     enable_http2 : Bool = true,
                     enable_caching : Bool = true,
                     cache_size : Int64 = 100_000_000,
                     enable_realtime_auth : Bool = false,
                     enable_realtime_rate_limiting : Bool = true,
                     connection_cleanup_interval : Time::Span = 5.minutes,
                     security_config : Security::SecurityConfig? = nil,
                     observability_config : Observability::ObservabilityConfig? = nil)
        
        @observability_config = observability_config || Observability::ObservabilityConfig.production
        
        # Initialize observability components BEFORE calling super
        setup_observability
        
        super(app_path, app_type, enable_http2, enable_caching, cache_size, 
              enable_realtime_auth, enable_realtime_rate_limiting, 
              connection_cleanup_interval, security_config)
        
        # Setup observability middleware after security middleware
        setup_observability_middleware
      end
      
      def configure_logging(service_name : String, environment : String = "production", **options)
        @logger = Observability::StructuredLogger.new(service_name, environment, **options)
        Observability.configure_logger(service_name, environment, **options)
        rebuild_middleware_stack
      end
      
      def configure_tracing(service_name : String, tracer_type : Symbol = :jaeger, **options)
        case tracer_type
        when :jaeger
          endpoint = options[:endpoint]?.try(&.as(String)) || "http://localhost:14268/api/traces"
          @tracer = Observability::JaegerTracer.new(service_name, endpoint)
        when :otlp
          endpoint = options[:endpoint]?.try(&.as(String)) || "http://localhost:4318/v1/traces"
          headers = options[:headers]?.try(&.as(Hash(String, String))) || {} of String => String
          @tracer = Observability::OTLPTracer.new(service_name, endpoint, headers)
        when :memory
          @tracer = Observability::InMemoryTracer.new
        else
          raise ArgumentError.new("Unsupported tracer type: #{tracer_type}")
        end
        
        if tracer = @tracer
          Observability::TracingManager.configure(tracer)
        end
        
        rebuild_middleware_stack
      end
      
      def add_health_check(check : Observability::HealthCheck)
        @health_manager.add_health_check(check)
      end
      
      def add_database_health_check(db_url : String, query : String = "SELECT 1")
        add_health_check(Observability::DatabaseHealthCheck.new(db_url, query))
      end
      
      def add_redis_health_check(redis_url : String)
        add_health_check(Observability::RedisHealthCheck.new(redis_url))
      end
      
      def add_http_health_check(url : String, expected_status : Int32 = 200)
        add_health_check(Observability::HttpHealthCheck.new(url, expected_status))
      end
      
      def add_shutdown_hook(hook : Observability::ShutdownHook)
        @shutdown_manager.add_hook(hook)
      end
      
      def health_status : Hash(String, Observability::HealthCheckResult)
        @health_manager.run_all_checks
      end
      
      def overall_health : {status: String, message: String}
        @health_manager.overall_health
      end
      
      def metrics : Hash(String, JSON::Any)
        @metrics_collector.get_metrics
      end
      
      def prometheus_metrics : String
        @metrics_collector.get_prometheus_format
      end
      
      def shutdown_gracefully(reason : String = "Manual shutdown") : Bool
        @shutdown_manager.shutdown(reason)
      end
      
      def update_observability_config(config : Observability::ObservabilityConfig)
        @observability_config = config
        setup_observability
      end
      
      # Class-level configuration methods
      def self.configure_observability(&block : Observability::ObservabilityConfig -> Nil)
        config = Observability::ObservabilityConfig.new
        block.call(config)
        instance.update_observability_config(config)
      end
      
      def self.enable_structured_logging(service_name : String, **options)
        instance.configure_logging(service_name, **options)
      end
      
      def self.enable_distributed_tracing(service_name : String, tracer_type : Symbol = :jaeger, **options)
        instance.configure_tracing(service_name, tracer_type, **options)
      end
      
      def self.add_health_checks(&block : Observability::HealthCheckManager -> Nil)
        block.call(instance.@health_manager)
      end
      
      # Enhanced serve method with observability
      def serve(port=8080, host="0.0.0.0", workers : Int32 = System.cpu_count)
        @port = port.to_i
        
        # Log startup with full configuration
        startup_info = {
          service: LogContext.get("service") || @name,
          version: LogContext.get("version") || "unknown",
          environment: @observability_config.environment,
          host: host,
          port: @port,
          workers: workers,
          features: {
            http2: @enable_http2,
            caching: @enable_caching,
            security: @security_config.security_level,
            tracing: !@tracer.nil?,
            metrics: true,
            health_checks: @health_manager.stats["total_checks"],
            graceful_shutdown: true
          }
        }
        
        @logger.info("Starting Observable Amethyst Server", **startup_info.transform_values(&.to_s))
        
        # Start background observability tasks
        start_background_tasks
        
        begin
          if workers > 1
            serve_multi_threaded(host, port, workers)
          else
            serve_single_threaded(host, port)
          end
        rescue ex
          @logger.error("Server startup failed", error: ex)
          raise ex
        end
      end
      
      def observability_stats
        {
          logging: {
            service: LogContext.get("service"),
            environment: @observability_config.environment,
            level: @observability_config.log_level.to_s
          },
          tracing: {
            enabled: !@tracer.nil?,
            tracer_type: @tracer.try(&.class.name) || "none"
          },
          health_checks: @health_manager.stats,
          metrics: {
            total_metrics: @metrics_collector.get_metrics.size,
            collection_enabled: @observability_config.enable_metrics
          },
          shutdown: @shutdown_manager.status
        }
      end
      
      private def setup_observability
        # Configure structured logging
        service_name = LogContext.get("service") || @name
        @logger = Observability::StructuredLogger.new(
          service_name, 
          @observability_config.environment,
          version: LogContext.get("version"),
          min_level: @observability_config.log_level,
          include_caller: @observability_config.include_caller
        )
        
        # Add console output
        console_output = Observability::ConsoleOutput.new(
          STDOUT, 
          @observability_config.colorized_logs,
          @observability_config.json_logs
        )
        @logger.add_output(console_output)
        
        # Add file output if configured
        if log_file = @observability_config.log_file
          file_output = Observability::FileOutput.new(log_file)
          @logger.add_output(file_output)
        end
        
        # Configure global logger
        Observability.configure_logger(service_name, @observability_config.environment)
        
        # Configure metrics collector
        @metrics_collector = Observability::MetricsCollector.new
        Observability.configure_metrics
        
        # Configure health check manager  
        @health_manager = Observability::HealthCheckManager.new(
          cache_ttl: @observability_config.health_check_cache_ttl,
          logger: @logger
        )
        
        # Add default health checks
        add_default_health_checks
        
        # Configure graceful shutdown
        @shutdown_manager = Observability::GracefulShutdownManager.new(
          @observability_config.shutdown_timeout,
          @logger
        )
        Observability.configure_shutdown(@observability_config.shutdown_timeout, @logger)
      end
      
      private def setup_observability_middleware
        # Add observability middleware to the stack (after security middleware)
        
        # 1. Request tracking for graceful shutdown
        request_tracking = Observability::RequestTrackingMiddleware.new(nil, @shutdown_manager)
        self.class.use request_tracking
        
        # 2. Correlation ID middleware
        correlation_middleware = Observability::CorrelationMiddleware.new(nil, logger: @logger)
        self.class.use correlation_middleware
        
        # 3. Distributed tracing middleware
        if @tracer
          tracing_middleware = Observability::TracingMiddleware.new(nil, logger: @logger)
          self.class.use tracing_middleware
        end
        
        # 4. Request logging middleware
        if @observability_config.log_requests
          request_logger = Observability::RequestLogger.new(
            nil, 
            @logger,
            log_request_body: @observability_config.log_request_bodies,
            log_response_body: @observability_config.log_response_bodies
          )
          self.class.use request_logger
        end
        
        # 5. Metrics collection middleware
        metrics_middleware = MetricsMiddleware.new(nil, @metrics_collector)
        self.class.use metrics_middleware
        
        rebuild_middleware_stack
      end
      
      private def add_default_health_checks
        # Add application health check
        app_check = Observability::ApplicationHealthCheck.new(
          LogContext.get("service") || @name,
          LogContext.get("version")
        )
        @health_manager.add_check(app_check)
        
        # Add memory health check
        memory_check = Observability::MemoryHealthCheck.new
        @health_manager.add_check(memory_check)
        
        # Add disk space health check
        disk_check = Observability::DiskSpaceHealthCheck.new
        @health_manager.add_check(disk_check)
        
        # Add shutdown readiness check
        shutdown_check = Observability::ShutdownReadinessCheck.new(@shutdown_manager)
        @health_manager.add_check(shutdown_check)
      end
      
      private def start_background_tasks
        # Start metrics collection task
        spawn do
          loop do
            sleep 30.seconds
            
            # Update system metrics
            @metrics_collector.gauge("active_connections", get_active_connections.to_f64)
            @metrics_collector.gauge("memory_usage_mb", get_memory_usage_mb)
            @metrics_collector.gauge("cpu_usage_percent", get_cpu_usage_percent)
            
            # Update health check metrics
            health_stats = @health_manager.stats
            @metrics_collector.gauge("health_checks_total", health_stats["total_checks"].to_f64)
            @metrics_collector.gauge("health_checks_healthy", health_stats["healthy_checks"].to_f64)
            @metrics_collector.gauge("health_checks_unhealthy", health_stats["unhealthy_checks"].to_f64)
          end
        end
        
        # Start periodic health check task
        spawn do
          loop do
            sleep @observability_config.health_check_interval
            
            begin
              # Run all health checks and log critical failures
              results = @health_manager.run_all_checks
              
              critical_failures = results.select do |name, result|
                check = @health_manager.@checks[name]?
                check && check.critical? && !result.healthy?
              end
              
              if critical_failures.any?
                @logger.error("Critical health checks failing", 
                  failed_checks: critical_failures.keys.join(", "),
                  total_failed: critical_failures.size
                )
              end
            rescue ex
              @logger.error("Health check task failed", error: ex)
            end
          end
        end
        
        # Start log correlation cleanup task
        spawn do
          loop do
            sleep 1.hour
            
            # This would clean up old correlation data if needed
            @logger.debug("Performing periodic maintenance")
          end
        end
      end
      
      private def get_active_connections : Int32
        # This would return actual connection count
        Random.rand(1..100)
      end
      
      private def get_memory_usage_mb : Float64
        GC.stats.heap_size.to_f64 / (1024 * 1024)
      end
      
      private def get_cpu_usage_percent : Float64
        # This would return actual CPU usage
        Random.rand(0.0..100.0)
      end
      
      private def self.instance
        @@instance ||= new(__FILE__)
      end
      
      # Metrics collection middleware
      private class MetricsMiddleware < Middleware::Base
        @metrics : Observability::MetricsCollector
        
        def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
          super(@app)
          @metrics = Observability::MetricsCollector.new
        end
        
        def call(request) : Http::Response
          start_time = Time.monotonic
          
          begin
            response = @app.call(request)
            
            duration = (Time.monotonic - start_time).total_milliseconds
            
            # Record request metrics
            @metrics.record_request(
              request.method,
              request.path,
              response.status_code,
              duration
            )
            
            response
          rescue ex
            duration = (Time.monotonic - start_time).total_milliseconds
            
            # Record error metrics
            @metrics.increment("http_errors_total", 1, {
              "method" => request.method,
              "path" => request.path,
              "error_type" => ex.class.name
            })
            
            @metrics.histogram("http_error_duration_ms", duration, {
              "method" => request.method,
              "path" => request.path
            })
            
            raise ex
          end
        end
      end
    end
  end
  
  # Observability configuration
  module Observability
    class ObservabilityConfig
      property environment : String
      property log_level : LogLevel
      property log_file : String?
      property json_logs : Bool
      property colorized_logs : Bool
      property include_caller : Bool
      property log_requests : Bool
      property log_request_bodies : Bool
      property log_response_bodies : Bool
      property enable_metrics : Bool
      property health_check_interval : Time::Span
      property health_check_cache_ttl : Time::Span
      property shutdown_timeout : Time::Span
      
      def initialize(@environment : String = "production",
                     @log_level : LogLevel = LogLevel::INFO,
                     @log_file : String? = nil,
                     @json_logs : Bool = false,
                     @colorized_logs : Bool = true,
                     @include_caller : Bool = false,
                     @log_requests : Bool = true,
                     @log_request_bodies : Bool = false,
                     @log_response_bodies : Bool = false,
                     @enable_metrics : Bool = true,
                     @health_check_interval : Time::Span = 30.seconds,
                     @health_check_cache_ttl : Time::Span = 10.seconds,
                     @shutdown_timeout : Time::Span = 30.seconds)
      end
      
      def self.development : ObservabilityConfig
        new(
          environment: "development",
          log_level: LogLevel::DEBUG,
          json_logs: false,
          colorized_logs: true,
          include_caller: true,
          log_requests: true,
          log_request_bodies: true,
          log_response_bodies: true,
          shutdown_timeout: 10.seconds
        )
      end
      
      def self.production : ObservabilityConfig
        new(
          environment: "production",
          log_level: LogLevel::INFO,
          log_file: "/var/log/amethyst.log",
          json_logs: true,
          colorized_logs: false,
          include_caller: false,
          log_requests: true,
          log_request_bodies: false,
          log_response_bodies: false,
          shutdown_timeout: 30.seconds
        )
      end
      
      def self.testing : ObservabilityConfig
        new(
          environment: "testing",
          log_level: LogLevel::WARN,
          json_logs: false,
          colorized_logs: false,
          include_caller: false,
          log_requests: false,
          enable_metrics: false,
          shutdown_timeout: 5.seconds
        )
      end
    end
  end
end