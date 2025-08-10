module Amethyst
  module Config
    # Observability configuration for logging, tracing, and metrics
    class ObservabilityConfig
      # Structured Logging
      property logging_enabled : Bool = true
      property log_level : String = "info"
      property log_format : String = "json" # json, text, or custom
      property log_correlation_id : Bool = true
      property log_request_id : Bool = true
      property correlation_header : String = "X-Correlation-ID"
      property log_request_body : Bool = false
      property log_response_body : Bool = false
      property log_max_body_size : Int32 = 1024
      property log_skip_paths : Set(String) = Set{"/health", "/metrics", "/favicon.ico"}
      
      # Distributed Tracing
      property tracing_enabled : Bool = false
      property tracing_service_name : String = "amethyst-app"
      property tracing_endpoint : String? = nil
      property tracing_sample_rate : Float64 = 1.0
      property trace_context_propagation : Bool = true
      property trace_headers : Array(String) = ["User-Agent", "Content-Type"]
      
      # Metrics Collection
      property metrics_enabled : Bool = false
      property metrics_endpoint : String = "/metrics"
      property metrics_port : Int32? = nil # Use same port as app if nil
      property collect_http_metrics : Bool = true
      property collect_db_metrics : Bool = true
      property collect_custom_metrics : Bool = true
      property histogram_buckets : Array(Float64) = [0.1, 0.5, 1.0, 2.5, 5.0, 10.0]
      
      # Health Checks
      property health_checks_enabled : Bool = true
      property health_endpoint : String = "/health"
      property detailed_health : Bool = false
      property health_check_timeout : Time::Span = 5.seconds
      property health_dependencies : Array(String) = [] of String
      
      # Performance Monitoring
      property performance_monitoring : Bool = true
      property slow_request_threshold : Time::Span = 1.second
      property memory_monitoring : Bool = true
      property gc_monitoring : Bool = true
      property fiber_monitoring : Bool = false
      
      # Error Reporting
      property error_reporting : Bool = true
      property error_sampling_rate : Float64 = 1.0
      property error_skip_types : Array(String) = ["Amethyst::Exceptions::NotFound"]
      property include_stacktrace : Bool = true
      property max_stacktrace_depth : Int32 = 50
      
      def self.development
        config = new
        config.log_level = "debug"
        config.log_format = "text"
        config.tracing_enabled = false
        config.metrics_enabled = false
        config.detailed_health = true
        config.log_request_body = true
        config.log_response_body = true
        config
      end
      
      def self.production
        config = new
        config.log_level = "info"
        config.log_format = "json"
        config.tracing_enabled = true
        config.metrics_enabled = true
        config.detailed_health = false
        config.log_request_body = false
        config.log_response_body = false
        config
      end
      
      def self.testing
        config = new
        config.log_level = "warn"
        config.logging_enabled = false
        config.tracing_enabled = false
        config.metrics_enabled = false
        config.health_checks_enabled = false
        config
      end
      
      # Fluent configuration methods
      def structured_logging(enabled : Bool = true, **options)
        @logging_enabled = enabled
        options.each { |key, value|
          case key
          when :level then @log_level = value.as(String) if value.is_a?(String)
          when :format then @log_format = value.as(String) if value.is_a?(String)
          when :correlation_id then @log_correlation_id = value.as(Bool) if value.is_a?(Bool)
          when :request_id then @log_request_id = value.as(Bool) if value.is_a?(Bool)
          when :correlation_header then @correlation_header = value.as(String) if value.is_a?(String)
          when :log_request_body then @log_request_body = value.as(Bool) if value.is_a?(Bool)
          when :log_response_body then @log_response_body = value.as(Bool) if value.is_a?(Bool)
          when :max_body_size then @log_max_body_size = value.as(Int32) if value.is_a?(Int32)
          when :skip_paths then @log_skip_paths = value.as(Set(String)) if value.is_a?(Set(String))
          end
        }
        self
      end
      
      def distributed_tracing(enabled : Bool = true, **options)
        @tracing_enabled = enabled
        options.each { |key, value|
          case key
          when :service_name then @tracing_service_name = value.as(String)
          when :endpoint then @tracing_endpoint = value.as(String?)
          when :sample_rate then @tracing_sample_rate = value.as(Float64)
          when :context_propagation then @trace_context_propagation = value.as(Bool)
          when :headers then @trace_headers = value.as(Array(String))
          end
        }
        self
      end
      
      def metrics(enabled : Bool = true, **options)
        @metrics_enabled = enabled
        options.each { |key, value|
          case key
          when :endpoint then @metrics_endpoint = value.as(String)
          when :port then @metrics_port = value.as(Int32?)
          when :collect_http then @collect_http_metrics = value.as(Bool)
          when :collect_db then @collect_db_metrics = value.as(Bool)
          when :collect_custom then @collect_custom_metrics = value.as(Bool)
          when :histogram_buckets then @histogram_buckets = value.as(Array(Float64))
          end
        }
        self
      end
      
      def health_checks(enabled : Bool = true, **options)
        @health_checks_enabled = enabled
        options.each { |key, value|
          case key
          when :endpoint then @health_endpoint = value.as(String)
          when :detailed then @detailed_health = value.as(Bool)
          when :timeout then @health_check_timeout = value.as(Time::Span)
          when :dependencies then @health_dependencies = value.as(Array(String))
          end
        }
        self
      end
      
      def performance_monitoring(enabled : Bool = true, **options)
        @performance_monitoring = enabled
        options.each { |key, value|
          case key
          when :slow_threshold then @slow_request_threshold = value.as(Time::Span)
          when :memory_monitoring then @memory_monitoring = value.as(Bool)
          when :gc_monitoring then @gc_monitoring = value.as(Bool)
          when :fiber_monitoring then @fiber_monitoring = value.as(Bool)
          end
        }
        self
      end
      
      def error_reporting(enabled : Bool = true, **options)
        @error_reporting = enabled
        options.each { |key, value|
          case key
          when :sampling_rate then @error_sampling_rate = value.as(Float64)
          when :skip_types then @error_skip_types = value.as(Array(String))
          when :include_stacktrace then @include_stacktrace = value.as(Bool)
          when :max_stacktrace_depth then @max_stacktrace_depth = value.as(Int32)
          end
        }
        self
      end
    end
  end
end