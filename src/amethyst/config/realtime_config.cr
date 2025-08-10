module Amethyst
  module Config
    # Realtime configuration for WebSockets and SSE
    class RealtimeConfig
      # WebSocket settings
      property websockets_enabled : Bool = false
      property ws_heartbeat_interval : Time::Span = 30.seconds
      property ws_max_connections : Int32 = 1000
      property ws_message_size_limit : Int32 = 1024 * 1024 # 1MB
      property ws_compression_enabled : Bool = true
      property ws_per_message_deflate : Bool = true
      
      # Server-Sent Events settings
      property sse_enabled : Bool = false
      property sse_heartbeat_interval : Time::Span = 30.seconds
      property sse_retry_interval : Int32 = 3000
      property sse_history_size : Int32 = 100
      property sse_cors_enabled : Bool = true
      property sse_allowed_origins : Array(String) = ["*"]
      
      # Authentication
      property realtime_auth_enabled : Bool = false
      property auth_token_header : String = "Authorization"
      property auth_required_routes : Set(String) = Set(String).new
      property auth_optional_routes : Set(String) = Set(String).new
      
      # Rate Limiting for Realtime
      property realtime_rate_limiting : Bool = true
      property max_connections_per_ip : Int32 = 10
      property max_messages_per_minute : Int32 = 100
      property rate_limit_window : Time::Span = 1.minute
      
      # Connection Management
      property connection_cleanup_interval : Time::Span = 5.minutes
      property idle_connection_timeout : Time::Span = 10.minutes
      property ping_pong_timeout : Time::Span = 60.seconds
      
      def self.development
        config = new
        config.websockets_enabled = true
        config.sse_enabled = true
        config.realtime_auth_enabled = false
        config.realtime_rate_limiting = false
        config
      end
      
      def self.production
        config = new
        config.websockets_enabled = true
        config.sse_enabled = true
        config.realtime_auth_enabled = true
        config.realtime_rate_limiting = true
        config
      end
      
      def self.testing
        config = new
        config.websockets_enabled = false
        config.sse_enabled = false
        config.realtime_rate_limiting = false
        config
      end
      
      # Fluent configuration methods
      def websockets(enabled : Bool = true, **options)
        @websockets_enabled = enabled
        options.each { |key, value|
          case key
          when :heartbeat_interval then @ws_heartbeat_interval = value.as(Time::Span)
          when :max_connections then @ws_max_connections = value.as(Int32)
          when :message_size_limit then @ws_message_size_limit = value.as(Int32)
          when :compression then @ws_compression_enabled = value.as(Bool)
          when :per_message_deflate then @ws_per_message_deflate = value.as(Bool)
          end
        }
        self
      end
      
      def server_sent_events(enabled : Bool = true, **options)
        @sse_enabled = enabled
        options.each { |key, value|
          case key
          when :heartbeat_interval then @sse_heartbeat_interval = value.as(Time::Span)
          when :retry_interval then @sse_retry_interval = value.as(Int32)
          when :history_size then @sse_history_size = value.as(Int32)
          when :cors_enabled then @sse_cors_enabled = value.as(Bool)
          when :allowed_origins then @sse_allowed_origins = value.as(Array(String))
          end
        }
        self
      end
      
      def authentication(enabled : Bool = true, **options)
        @realtime_auth_enabled = enabled
        options.each { |key, value|
          case key
          when :token_header then @auth_token_header = value.as(String)
          when :required_routes then @auth_required_routes = value.as(Set(String))
          when :optional_routes then @auth_optional_routes = value.as(Set(String))
          end
        }
        self
      end
      
      def rate_limiting(enabled : Bool = true, **options)
        @realtime_rate_limiting = enabled
        options.each { |key, value|
          case key
          when :max_connections_per_ip then @max_connections_per_ip = value.as(Int32)
          when :max_messages_per_minute then @max_messages_per_minute = value.as(Int32)
          when :window then @rate_limit_window = value.as(Time::Span)
          end
        }
        self
      end
      
      def connection_management(**options)
        options.each { |key, value|
          case key
          when :cleanup_interval then @connection_cleanup_interval = value.as(Time::Span)
          when :idle_timeout then @idle_connection_timeout = value.as(Time::Span)
          when :ping_pong_timeout then @ping_pong_timeout = value.as(Time::Span)
          end
        }
        self
      end
    end
  end
end