module Amethyst
  module Config
    # Performance configuration with sensible defaults
    class PerformanceConfig
      # Connection Pooling
      property connection_pool_enabled : Bool = true
      property max_connections : Int32 = 25
      property connection_timeout : Time::Span = 30.seconds
      property connection_idle_timeout : Time::Span = 5.minutes
      
      # Caching
      property caching_enabled : Bool = true
      property cache_size_mb : Int64 = 100
      property default_cache_ttl : Time::Span = 5.minutes
      property etag_enabled : Bool = true
      property conditional_get_enabled : Bool = true
      
      # Static Files
      property static_file_serving : Bool = true
      property zero_copy_enabled : Bool = true
      property gzip_compression : Bool = true
      property static_cache_max_age : Int32 = 86400 # 1 day
      property static_directories : Array(String) = ["public"]
      
      # HTTP/2 and HTTP/3
      property http2_enabled : Bool = false
      property http3_enabled : Bool = false
      property server_push_enabled : Bool = false
      
      # Routing
      property compiled_routes : Bool = true
      property route_caching : Bool = true
      property route_cache_size : Int32 = 1000
      
      def self.development
        config = new
        config.caching_enabled = false  # Easier for development
        config.zero_copy_enabled = false
        config.gzip_compression = false
        config.compiled_routes = false  # Faster compilation
        config
      end
      
      def self.production
        config = new
        config.http2_enabled = true
        config.gzip_compression = true
        config
      end
      
      def self.testing
        config = new
        config.caching_enabled = false
        config.connection_pool_enabled = false
        config.compiled_routes = false
        config
      end
      
      # Fluent configuration methods
      def connection_pooling(enabled : Bool = true, **options)
        @connection_pool_enabled = enabled
        options.each { |key, value|
          case key
          when :max_connections then @max_connections = value.as(Int32) if value.is_a?(Int32)
          when :timeout 
            if value.is_a?(Time::Span)
              @connection_timeout = value
            elsif value.is_a?(Int32)
              @connection_timeout = value.seconds
            end
          when :idle_timeout
            if value.is_a?(Time::Span)
              @connection_idle_timeout = value
            elsif value.is_a?(Int32)
              @connection_idle_timeout = value.seconds
            end
          end
        }
        self
      end
      
      def caching(enabled : Bool = true, **options)
        @caching_enabled = enabled
        options.each { |key, value|
          case key
          when :size_mb then @cache_size_mb = value.as(Int64) if value.is_a?(Int64)
          when :default_ttl 
            if value.is_a?(Time::Span)
              @default_cache_ttl = value
            elsif value.is_a?(Int32)
              @default_cache_ttl = value.seconds
            end
          when :etag_enabled then @etag_enabled = value.as(Bool) if value.is_a?(Bool)
          when :conditional_get then @conditional_get_enabled = value.as(Bool) if value.is_a?(Bool)
          end
        }
        self
      end
      
      def static_files(enabled : Bool = true, **options)
        @static_file_serving = enabled
        options.each { |key, value|
          case key
          when :zero_copy then @zero_copy_enabled = value.as(Bool) if value.is_a?(Bool)
          when :gzip then @gzip_compression = value.as(Bool) if value.is_a?(Bool)
          when :max_age then @static_cache_max_age = value.as(Int32) if value.is_a?(Int32)
          when :directories then @static_directories = value.as(Array(String)) if value.is_a?(Array(String))
          end
        }
        self
      end
      
      def http2(enabled : Bool = true, **options)
        @http2_enabled = enabled
        options.each { |key, value|
          case key
          when :server_push then @server_push_enabled = value.as(Bool)
          end
        }
        self
      end
      
      def routing(compiled : Bool = true, **options)
        @compiled_routes = compiled
        options.each { |key, value|
          case key
          when :caching then @route_caching = value.as(Bool)
          when :cache_size then @route_cache_size = value.as(Int32)
          end
        }
        self
      end
    end
  end
end