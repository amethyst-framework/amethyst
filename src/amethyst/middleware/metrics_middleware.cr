require "./base"
require "../http/request"
require "../http/response"

module Amethyst
  module Middleware
    # Middleware for collecting HTTP metrics
    class MetricsMiddleware < Base
      @request_counter = {} of String => Int64
      @response_time_histogram = {} of String => Array(Float64)
      @active_requests = 0_i64
      @total_requests = 0_i64
      @total_errors = 0_i64
      
      def initialize(@app : Base | Routing::OptimizedRouter? = nil)
        super(@app)
      end
      
      def call(request : Http::Request) : Http::Response
        start_time = Time.monotonic
        @total_requests += 1
        @active_requests += 1
        
        method_path = "#{request.method} #{request.path}"
        @request_counter[method_path] = (@request_counter[method_path]? || 0_i64) + 1
        
        begin
          response = super(request)
          
          # Record response time
          duration = (Time.monotonic - start_time).total_seconds
          @response_time_histogram[method_path] ||= [] of Float64
          @response_time_histogram[method_path] << duration
          
          # Track errors (4xx and 5xx responses)
          if response.status >= 400
            @total_errors += 1
          end
          
          response
        rescue ex
          @total_errors += 1
          raise ex
        ensure
          @active_requests -= 1
        end
      end
      
      # Get current metrics (called by MetricsController)
      def self.get_metrics
        String.build do |str|
          str << "# HELP amethyst_http_requests_total Total HTTP requests\n"
          str << "# TYPE amethyst_http_requests_total counter\n"
          
          instance = @@instance
          if instance
            instance.@request_counter.each do |route, count|
              method, path = route.split(" ", 2)
              str << "amethyst_http_requests_total{method=\"#{method}\",path=\"#{path}\"} #{count}\n"
            end
          end
          
          str << "\n# HELP amethyst_http_request_duration_seconds HTTP request duration\n"
          str << "# TYPE amethyst_http_request_duration_seconds histogram\n"
          
          if instance
            instance.@response_time_histogram.each do |route, times|
              next if times.empty?
              
              method, path = route.split(" ", 2)
              sorted_times = times.sort
              
              # Calculate histogram buckets
              buckets = [0.1, 0.5, 1.0, 2.5, 5.0, 10.0]
              buckets.each do |bucket|
                count = sorted_times.count { |t| t <= bucket }
                str << "amethyst_http_request_duration_seconds_bucket{method=\"#{method}\",path=\"#{path}\",le=\"#{bucket}\"} #{count}\n"
              end
              
              # +Inf bucket
              str << "amethyst_http_request_duration_seconds_bucket{method=\"#{method}\",path=\"#{path}\",le=\"+Inf\"} #{times.size}\n"
              
              # Sum and count
              sum = times.sum
              str << "amethyst_http_request_duration_seconds_sum{method=\"#{method}\",path=\"#{path}\"} #{sum}\n"
              str << "amethyst_http_request_duration_seconds_count{method=\"#{method}\",path=\"#{path}\"} #{times.size}\n"
            end
          end
          
          str << "\n# HELP amethyst_http_requests_active Currently active HTTP requests\n"
          str << "# TYPE amethyst_http_requests_active gauge\n"
          str << "amethyst_http_requests_active #{instance ? instance.@active_requests : 0}\n"
          
          str << "\n# HELP amethyst_http_requests_total_count Total HTTP requests processed\n"
          str << "# TYPE amethyst_http_requests_total_count counter\n"
          str << "amethyst_http_requests_total_count #{instance ? instance.@total_requests : 0}\n"
          
          str << "\n# HELP amethyst_http_errors_total Total HTTP errors (4xx, 5xx)\n"
          str << "# TYPE amethyst_http_errors_total counter\n"
          str << "amethyst_http_errors_total #{instance ? instance.@total_errors : 0}\n"
          
          str << "\n# HELP amethyst_memory_usage_bytes Current memory usage\n"
          str << "# TYPE amethyst_memory_usage_bytes gauge\n"
          str << "amethyst_memory_usage_bytes #{GC.stats.heap_size}\n"
        end
      end
      
      # Singleton for global metrics collection
      @@instance : MetricsMiddleware?
      
      def self.instance
        @@instance ||= new
      end
      
      def self.instance=(middleware : MetricsMiddleware)
        @@instance = middleware
      end
    end
  end
end