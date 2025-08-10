require "json"
require "./structured_logging"

module Amethyst
  module Observability
    # Health check status
    enum HealthStatus
      UP
      DOWN
      DEGRADED
      UNKNOWN
    end
    
    # Health check result
    struct HealthCheckResult
      include JSON::Serializable
      
      property name : String
      property status : String
      property message : String?
      property duration_ms : Float64
      property timestamp : String
      property details : Hash(String, JSON::Any)?
      property error : String?
      
      def initialize(@name : String, @status : String, @duration_ms : Float64, 
                     @message : String? = nil, @details : Hash(String, JSON::Any)? = nil, 
                     @error : String? = nil)
        @timestamp = Time.utc.to_rfc3339
      end
      
      def healthy? : Bool
        @status == "UP"
      end
      
      def degraded? : Bool
        @status == "DEGRADED"
      end
      
      def unhealthy? : Bool
        @status == "DOWN"
      end
    end
    
    # Health check interface
    abstract class HealthCheck
      abstract def check : HealthCheckResult
      abstract def name : String
      
      def timeout : Time::Span
        5.seconds
      end
      
      def critical? : Bool
        true
      end
      
      protected def measure_time(&block : -> HealthCheckResult) : HealthCheckResult
        start_time = Time.monotonic
        result = yield
        duration = (Time.monotonic - start_time).total_milliseconds
        result.duration_ms = duration
        result
      end
    end
    
    # Database health check
    class DatabaseHealthCheck < HealthCheck
      @db_url : String
      @query : String
      @timeout : Time::Span
      
      def initialize(@db_url : String, @query : String = "SELECT 1", @timeout : Time::Span = 3.seconds)
      end
      
      def name : String
        "database"
      end
      
      def timeout : Time::Span
        @timeout
      end
      
      def check : HealthCheckResult
        measure_time do
          begin
            # This would connect to your actual database
            # For now, simulate a database check
            if @db_url.includes?("localhost")
              HealthCheckResult.new(name, "UP", 0.0, "Database connection successful")
            else
              HealthCheckResult.new(name, "DOWN", 0.0, "Cannot connect to database", 
                error: "Connection refused")
            end
          rescue ex
            HealthCheckResult.new(name, "DOWN", 0.0, "Database check failed", 
              error: ex.message)
          end
        end
      end
    end
    
    # Redis health check
    class RedisHealthCheck < HealthCheck
      @redis_url : String
      @timeout : Time::Span
      
      def initialize(@redis_url : String, @timeout : Time::Span = 2.seconds)
      end
      
      def name : String
        "redis"
      end
      
      def timeout : Time::Span
        @timeout
      end
      
      def check : HealthCheckResult
        measure_time do
          begin
            # This would connect to Redis
            # For now, simulate a Redis check
            details = {
              "redis_version" => JSON::Any.new("6.2.0"),
              "connected_clients" => JSON::Any.new(5),
              "memory_usage" => JSON::Any.new("2MB")
            }
            
            HealthCheckResult.new(name, "UP", 0.0, "Redis connection successful", details)
          rescue ex
            HealthCheckResult.new(name, "DOWN", 0.0, "Redis check failed", 
              error: ex.message)
          end
        end
      end
      
      def critical? : Bool
        false  # Redis is not critical for app to function
      end
    end
    
    # HTTP endpoint health check
    class HttpHealthCheck < HealthCheck
      @url : String
      @expected_status : Int32
      @timeout : Time::Span
      @method : String
      @headers : ::HTTP::Headers?
      
      def initialize(@url : String, @expected_status : Int32 = 200, @timeout : Time::Span = 5.seconds,
                     @method : String = "GET", @headers : ::HTTP::Headers? = nil)
      end
      
      def name : String
        "http_#{URI.parse(@url).host || "unknown"}"
      end
      
      def timeout : Time::Span
        @timeout
      end
      
      def check : HealthCheckResult
        measure_time do
          begin
            uri = URI.parse(@url)
            client = ::HTTP::Client.new(uri.host.not_nil!, uri.port || 80)
            client.connect_timeout = @timeout
            client.read_timeout = @timeout
            
            response = client.exec(@method, uri.full_path, @headers)
            client.close
            
            if response.status_code == @expected_status
              HealthCheckResult.new(name, "UP", 0.0, "HTTP endpoint responding", {
                "status_code" => JSON::Any.new(response.status_code),
                "response_size" => JSON::Any.new(response.body.bytesize)
              })
            else
              HealthCheckResult.new(name, "DOWN", 0.0, "HTTP endpoint returned unexpected status", 
                error: "Expected #{@expected_status}, got #{response.status_code}")
            end
          rescue ex
            HealthCheckResult.new(name, "DOWN", 0.0, "HTTP endpoint check failed", 
              error: ex.message)
          end
        end
      end
      
      def critical? : Bool
        false  # External HTTP endpoints usually not critical
      end
    end
    
    # Disk space health check
    class DiskSpaceHealthCheck < HealthCheck
      @path : String
      @warning_threshold : Float64
      @critical_threshold : Float64
      
      def initialize(@path : String = "/", @warning_threshold : Float64 = 80.0, @critical_threshold : Float64 = 90.0)
      end
      
      def name : String
        "disk_space"
      end
      
      def check : HealthCheckResult
        measure_time do
          begin
            # This would check actual disk usage
            # For now, simulate disk usage
            used_percent = Random.rand(0.0..95.0)
            
            status = case
                     when used_percent >= @critical_threshold then "DOWN"
                     when used_percent >= @warning_threshold then "DEGRADED"
                     else "UP"
                     end
            
            details = {
              "path" => JSON::Any.new(@path),
              "used_percent" => JSON::Any.new(used_percent),
              "warning_threshold" => JSON::Any.new(@warning_threshold),
              "critical_threshold" => JSON::Any.new(@critical_threshold)
            }
            
            message = case status
                     when "DOWN" then "Disk space critically low (#{used_percent.round(1)}%)"
                     when "DEGRADED" then "Disk space getting low (#{used_percent.round(1)}%)"
                     else "Disk space OK (#{used_percent.round(1)}%)"
                     end
            
            HealthCheckResult.new(name, status, 0.0, message, details)
          rescue ex
            HealthCheckResult.new(name, "DOWN", 0.0, "Disk space check failed", 
              error: ex.message)
          end
        end
      end
    end
    
    # Memory usage health check
    class MemoryHealthCheck < HealthCheck
      @warning_threshold : Float64
      @critical_threshold : Float64
      
      def initialize(@warning_threshold : Float64 = 80.0, @critical_threshold : Float64 = 90.0)
      end
      
      def name : String
        "memory"
      end
      
      def check : HealthCheckResult
        measure_time do
          begin
            # Get memory statistics (simplified)
            gc_stats = GC.stats
            memory_usage = gc_stats.heap_size.to_f64 / (1024 * 1024) # MB
            memory_limit = 512.0 # Assume 512MB limit for this example
            used_percent = (memory_usage / memory_limit) * 100
            
            status = case
                     when used_percent >= @critical_threshold then "DOWN"
                     when used_percent >= @warning_threshold then "DEGRADED"
                     else "UP"
                     end
            
            details = {
              "heap_size_mb" => JSON::Any.new(memory_usage.round(2)),
              "used_percent" => JSON::Any.new(used_percent.round(1)),
              "gc_collections" => JSON::Any.new(gc_stats.total_bytes),
              "warning_threshold" => JSON::Any.new(@warning_threshold),
              "critical_threshold" => JSON::Any.new(@critical_threshold)
            }
            
            message = case status
                     when "DOWN" then "Memory usage critically high (#{used_percent.round(1)}%)"
                     when "DEGRADED" then "Memory usage getting high (#{used_percent.round(1)}%)"
                     else "Memory usage OK (#{used_percent.round(1)}%)"
                     end
            
            HealthCheckResult.new(name, status, 0.0, message, details)
          rescue ex
            HealthCheckResult.new(name, "DOWN", 0.0, "Memory check failed", 
              error: ex.message)
          end
        end
      end
    end
    
    # Application-specific health check
    class ApplicationHealthCheck < HealthCheck
      @app_name : String
      @version : String?
      
      def initialize(@app_name : String, @version : String? = nil)
      end
      
      def name : String
        "application"
      end
      
      def check : HealthCheckResult
        measure_time do
          begin
            uptime = Time.utc.to_unix - @@start_time
            
            details = {
              "app_name" => JSON::Any.new(@app_name),
              "version" => JSON::Any.new(@version || "unknown"),
              "uptime_seconds" => JSON::Any.new(uptime),
              "environment" => JSON::Any.new(ENV["CRYSTAL_ENV"]? || "development"),
              "crystal_version" => JSON::Any.new(Crystal::VERSION)
            }
            
            HealthCheckResult.new(name, "UP", 0.0, "Application running normally", details)
          rescue ex
            HealthCheckResult.new(name, "DOWN", 0.0, "Application check failed", 
              error: ex.message)
          end
        end
      end
      
      @@start_time = Time.utc.to_unix
    end
    
    # Health check manager
    class HealthCheckManager
      @checks : Hash(String, HealthCheck)
      @cache : Hash(String, {result: HealthCheckResult, expires_at: Time})
      @cache_ttl : Time::Span
      @mutex : Mutex
      @logger : StructuredLogger?
      
      def initialize(@cache_ttl : Time::Span = 30.seconds, @logger : StructuredLogger? = nil)
        @checks = Hash(String, HealthCheck).new
        @cache = Hash(String, {result: HealthCheckResult, expires_at: Time}).new
        @mutex = Mutex.new
      end
      
      def add_check(check : HealthCheck)
        @mutex.synchronize do
          @checks[check.name] = check
        end
      end
      
      def remove_check(name : String)
        @mutex.synchronize do
          @checks.delete(name)
          @cache.delete(name)
        end
      end
      
      def run_check(name : String, force : Bool = false) : HealthCheckResult?
        check = @checks[name]?
        return nil unless check
        
        # Check cache first
        unless force
          @mutex.synchronize do
            cached = @cache[name]?
            if cached && cached[:expires_at] > Time.utc
              return cached[:result]
            end
          end
        end
        
        # Run the health check with timeout
        start_time = Time.monotonic
        result = nil
        
        begin
          channel = Channel(HealthCheckResult).new
          
          spawn do
            begin
              channel.send(check.check)
            rescue ex
              channel.send(HealthCheckResult.new(check.name, "DOWN", 0.0, "Check failed", 
                error: ex.message))
            end
          end
          
          select
          when result = channel.receive
            # Health check completed
          when timeout(check.timeout)
            result = HealthCheckResult.new(check.name, "DOWN", 
              (Time.monotonic - start_time).total_milliseconds,
              "Health check timed out", 
              error: "Timeout after #{check.timeout}")
          end
          
          # Cache the result
          @mutex.synchronize do
            @cache[name] = {result: result, expires_at: Time.utc + @cache_ttl}
          end
          
          # Log the result
          @logger.try do |logger|
            if result.healthy?
              logger.debug("Health check passed", 
                check: result.name, 
                duration_ms: result.duration_ms,
                status: result.status
              )
            else
              logger.warn("Health check failed", 
                check: result.name, 
                duration_ms: result.duration_ms,
                status: result.status,
                error: result.error
              )
            end
          end
          
          result
        rescue ex
          HealthCheckResult.new(check.name, "DOWN", 
            (Time.monotonic - start_time).total_milliseconds,
            "Health check exception", error: ex.message)
        end
      end
      
      def run_all_checks(force : Bool = false) : Hash(String, HealthCheckResult)
        results = Hash(String, HealthCheckResult).new
        
        @checks.each_key do |name|
          if result = run_check(name, force)
            results[name] = result
          end
        end
        
        results
      end
      
      def overall_health : {status: String, message: String}
        results = run_all_checks
        
        critical_failures = results.select { |name, result| 
          @checks[name].critical? && !result.healthy? 
        }
        
        degraded_checks = results.select { |name, result| 
          result.degraded? 
        }
        
        if critical_failures.any?
          {
            status: "DOWN", 
            message: "Critical health checks failing: #{critical_failures.keys.join(", ")}"
          }
        elsif degraded_checks.any?
          {
            status: "DEGRADED", 
            message: "Some health checks degraded: #{degraded_checks.keys.join(", ")}"
          }
        else
          {status: "UP", message: "All health checks passing"}
        end
      end
      
      def clear_cache
        @mutex.synchronize do
          @cache.clear
        end
      end
      
      def stats : Hash(String, Int32)
        results = run_all_checks
        
        {
          "total_checks" => results.size,
          "healthy_checks" => results.count { |_, result| result.healthy? },
          "degraded_checks" => results.count { |_, result| result.degraded? },
          "unhealthy_checks" => results.count { |_, result| result.unhealthy? },
          "cached_results" => @cache.size
        }
      end
    end
    
    # Metrics collector
    class MetricsCollector
      @counters : Hash(String, Int64)
      @gauges : Hash(String, Float64)
      @histograms : Hash(String, Array(Float64))
      @timers : Hash(String, Array(Float64))
      @labels : Hash(String, Hash(String, String))
      @mutex : Mutex
      @start_time : Time
      
      def initialize
        @counters = Hash(String, Int64).new
        @gauges = Hash(String, Float64).new
        @histograms = Hash(String, Array(Float64)).new
        @timers = Hash(String, Array(Float64)).new
        @labels = Hash(String, Hash(String, String)).new
        @mutex = Mutex.new
        @start_time = Time.utc
        
        # Initialize built-in metrics
        initialize_builtin_metrics
      end
      
      def increment(name : String, value : Int64 = 1, labels : Hash(String, String)? = nil)
        metric_name = build_metric_name(name, labels)
        
        @mutex.synchronize do
          @counters[metric_name] = (@counters[metric_name]? || 0) + value
          @labels[metric_name] = labels if labels
        end
      end
      
      def gauge(name : String, value : Float64, labels : Hash(String, String)? = nil)
        metric_name = build_metric_name(name, labels)
        
        @mutex.synchronize do
          @gauges[metric_name] = value
          @labels[metric_name] = labels if labels
        end
      end
      
      def histogram(name : String, value : Float64, labels : Hash(String, String)? = nil)
        metric_name = build_metric_name(name, labels)
        
        @mutex.synchronize do
          @histograms[metric_name] ||= Array(Float64).new
          @histograms[metric_name] << value
          @labels[metric_name] = labels if labels
          
          # Keep only last 1000 values to prevent memory growth
          if @histograms[metric_name].size > 1000
            @histograms[metric_name] = @histograms[metric_name].last(1000)
          end
        end
      end
      
      def timer(name : String, labels : Hash(String, String)? = nil, &block)
        start_time = Time.monotonic
        result = yield
        duration = (Time.monotonic - start_time).total_milliseconds
        
        metric_name = build_metric_name(name, labels)
        
        @mutex.synchronize do
          @timers[metric_name] ||= Array(Float64).new
          @timers[metric_name] << duration
          @labels[metric_name] = labels if labels
          
          # Keep only last 1000 values
          if @timers[metric_name].size > 1000
            @timers[metric_name] = @timers[metric_name].last(1000)
          end
        end
        
        result
      end
      
      def record_request(method : String, path : String, status_code : Int32, duration_ms : Float64)
        increment("http_requests_total", 1, {
          "method" => method,
          "path" => path,
          "status" => status_code.to_s
        })
        
        histogram("http_request_duration_ms", duration_ms, {
          "method" => method,
          "path" => path
        })
        
        gauge("http_requests_in_flight", get_current_connections.to_f64)
      end
      
      def get_metrics : Hash(String, JSON::Any)
        @mutex.synchronize do
          metrics = Hash(String, JSON::Any).new
          
          # Counters
          @counters.each do |name, value|
            metrics["#{name}_total"] = JSON::Any.new(value)
          end
          
          # Gauges
          @gauges.each do |name, value|
            metrics[name] = JSON::Any.new(value)
          end
          
          # Histograms with percentiles
          @histograms.each do |name, values|
            next if values.empty?
            
            sorted = values.sort
            metrics["#{name}_count"] = JSON::Any.new(values.size)
            metrics["#{name}_sum"] = JSON::Any.new(values.sum)
            metrics["#{name}_avg"] = JSON::Any.new(values.sum / values.size)
            metrics["#{name}_min"] = JSON::Any.new(sorted.first)
            metrics["#{name}_max"] = JSON::Any.new(sorted.last)
            metrics["#{name}_p50"] = JSON::Any.new(percentile(sorted, 0.5))
            metrics["#{name}_p90"] = JSON::Any.new(percentile(sorted, 0.9))
            metrics["#{name}_p95"] = JSON::Any.new(percentile(sorted, 0.95))
            metrics["#{name}_p99"] = JSON::Any.new(percentile(sorted, 0.99))
          end
          
          # Timers (similar to histograms)
          @timers.each do |name, values|
            next if values.empty?
            
            sorted = values.sort
            metrics["#{name}_count"] = JSON::Any.new(values.size)
            metrics["#{name}_sum_ms"] = JSON::Any.new(values.sum)
            metrics["#{name}_avg_ms"] = JSON::Any.new(values.sum / values.size)
            metrics["#{name}_min_ms"] = JSON::Any.new(sorted.first)
            metrics["#{name}_max_ms"] = JSON::Any.new(sorted.last)
            metrics["#{name}_p50_ms"] = JSON::Any.new(percentile(sorted, 0.5))
            metrics["#{name}_p90_ms"] = JSON::Any.new(percentile(sorted, 0.9))
            metrics["#{name}_p95_ms"] = JSON::Any.new(percentile(sorted, 0.95))
            metrics["#{name}_p99_ms"] = JSON::Any.new(percentile(sorted, 0.99))
          end
          
          # Add runtime metrics
          add_runtime_metrics(metrics)
          
          metrics
        end
      end
      
      def get_prometheus_format : String
        metrics = get_metrics
        output = String::Builder.new
        
        metrics.each do |name, value|
          # Simple Prometheus format (without full TYPE and HELP metadata)
          output << "# TYPE #{name} gauge\n"
          output << "#{name} #{value}\n"
        end
        
        output.to_s
      end
      
      def reset
        @mutex.synchronize do
          @counters.clear
          @gauges.clear
          @histograms.clear
          @timers.clear
          @labels.clear
          initialize_builtin_metrics
        end
      end
      
      private def build_metric_name(name : String, labels : Hash(String, String)?) : String
        return name unless labels && !labels.empty?
        
        label_string = labels.map { |k, v| "#{k}=\"#{v}\"" }.join(",")
        "#{name}{#{label_string}}"
      end
      
      private def percentile(sorted_values : Array(Float64), p : Float64) : Float64
        return 0.0 if sorted_values.empty?
        
        index = (p * (sorted_values.size - 1)).round.to_i
        sorted_values[index]
      end
      
      private def get_current_connections : Int32
        # This would return actual connection count
        Random.rand(1..50)
      end
      
      private def initialize_builtin_metrics
        @gauges["app_start_time"] = @start_time.to_unix.to_f64
        @gauges["app_uptime_seconds"] = 0.0
        update_runtime_metrics
      end
      
      private def update_runtime_metrics
        @gauges["app_uptime_seconds"] = (Time.utc - @start_time).total_seconds
      end
      
      private def add_runtime_metrics(metrics : Hash(String, JSON::Any))
        update_runtime_metrics
        
        gc_stats = GC.stats
        metrics["gc_collections_total"] = JSON::Any.new(gc_stats.total_bytes)
        metrics["gc_heap_size_bytes"] = JSON::Any.new(gc_stats.heap_size)
        metrics["memory_usage_bytes"] = JSON::Any.new(gc_stats.heap_size)
        
        # Process metrics (simplified)
        metrics["process_cpu_seconds"] = JSON::Any.new((Time.utc - @start_time).total_seconds)
        metrics["process_open_fds"] = JSON::Any.new(Random.rand(10..100))
      end
    end
    
    # Global metrics instance
    @@metrics_collector : MetricsCollector?
    
    def self.configure_metrics
      @@metrics_collector = MetricsCollector.new
    end
    
    def self.metrics : MetricsCollector
      @@metrics_collector || raise "Metrics not configured. Call Observability.configure_metrics first."
    end
    
    def self.metrics? : MetricsCollector?
      @@metrics_collector
    end
  end
end