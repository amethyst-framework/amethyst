require "../base/optimized_app"
require "./realtime_router"
require "../controller"

module Amethyst
  module Base
    class RealtimeApp < OptimizedApp
      @realtime_router : Realtime::RealtimeRouter
      @realtime_middleware : Realtime::RealtimeMiddleware
      @connection_cleanup_interval : Time::Span
      @enable_realtime_auth : Bool
      @enable_realtime_rate_limiting : Bool
      
      def initialize(app_path, app_type={{@type.name.stringify}},
                     enable_http2 : Bool = true,
                     enable_caching : Bool = true,
                     cache_size : Int64 = 100_000_000,
                     enable_realtime_auth : Bool = false,
                     enable_realtime_rate_limiting : Bool = true,
                     connection_cleanup_interval : Time::Span = 5.minutes)
        
        super(app_path, app_type, enable_http2, enable_caching, cache_size)
        
        @enable_realtime_auth = enable_realtime_auth
        @enable_realtime_rate_limiting = enable_realtime_rate_limiting
        @connection_cleanup_interval = connection_cleanup_interval
        
        @realtime_router = Realtime::RealtimeRouter.new
        @realtime_middleware = Realtime::RealtimeMiddleware.new(nil, @realtime_router)
        
        setup_realtime_middleware
        start_connection_cleanup
      end
      
      def websocket(path : String, controller : WebSocket::Controller.class, **options)
        @realtime_router.websocket(path, controller, **options)
      end
      
      def websocket(path : String, &handler : WebSocket::Connection -> Nil)
        @realtime_router.websocket(path, &handler)
      end
      
      def sse(path : String, controller : SSE::Controller.class, **options)
        @realtime_router.sse(path, controller, **options)
      end
      
      def sse(path : String, &handler : SSE::Connection -> Nil)
        @realtime_router.sse(path, &handler)
      end
      
      def group(prefix : String, **options, &block)
        @realtime_router.group(prefix, **options, &block)
      end
      
      def namespace(name : String, &block)
        @realtime_router.namespace(name, &block)
      end
      
      def channel(name : String, &block)
        @realtime_router.channel(name, &block)
      end
      
      def broadcast_to_channel(channel : String, data : Hash | Array | String, 
                              event : String? = nil, id : String? = nil)
        Realtime::UnifiedConnectionManager.instance.broadcast_to_channel(channel, data, event, id)
      end
      
      def broadcast_to_all(data : Hash | Array | String, event : String? = nil, id : String? = nil)
        Realtime::UnifiedConnectionManager.instance.broadcast_to_all(data, event, id)
      end
      
      def realtime_stats
        {
          unified_manager: Realtime::UnifiedConnectionManager.instance.stats,
          router: @realtime_router.stats,
          routes: @realtime_router.routes_info
        }
      end
      
      def cleanup_connections
        Realtime::UnifiedConnectionManager.instance.cleanup_all_connections
      end
      
      # Class-level DSL methods
      def self.websocket(path : String, controller : WebSocket::Controller.class, **options)
        instance.websocket(path, controller, **options)
      end
      
      def self.websocket(path : String, &handler : WebSocket::Connection -> Nil)
        instance.websocket(path, &handler)
      end
      
      def self.sse(path : String, controller : SSE::Controller.class, **options)
        instance.sse(path, controller, **options)
      end
      
      def self.sse(path : String, &handler : SSE::Connection -> Nil)
        instance.sse(path, &handler)
      end
      
      def self.realtime_group(prefix : String, **options, &block)
        instance.group(prefix, **options, &block)
      end
      
      def self.realtime_namespace(name : String, &block)
        instance.namespace(name, &block)
      end
      
      def self.channel(name : String, &block)
        instance.channel(name, &block)
      end
      
      def self.broadcast_to_channel(channel : String, data : Hash | Array | String, 
                                   event : String? = nil, id : String? = nil)
        instance.broadcast_to_channel(channel, data, event, id)
      end
      
      def self.broadcast_to_all(data : Hash | Array | String, event : String? = nil, id : String? = nil)
        instance.broadcast_to_all(data, event, id)
      end
      
      private def setup_realtime_middleware
        # Add realtime authentication if enabled
        if @enable_realtime_auth
          auth_handler = ->(request : Http::Request) {
            # Default auth - override this in your app
            token = request.headers["Authorization"]?.try(&.gsub("Bearer ", ""))
            !token.nil? && !token.empty?
          }
          
          self.class.use Realtime::RealtimeAuth.new(nil, auth_handler)
        end
        
        # Add rate limiting if enabled
        if @enable_realtime_rate_limiting
          self.class.use Realtime::RealtimeRateLimit.new
        end
        
        # Add the main realtime middleware
        self.class.use @realtime_middleware
        
        # Rebuild middleware stack
        @app = Middleware::MiddlewareStack.instance.build_middleware
        @http_handler = Base::Handler.new(@app)
      end
      
      private def start_connection_cleanup
        spawn do
          loop do
            sleep @connection_cleanup_interval
            
            begin
              cleaned_count = cleanup_connections
              if cleaned_count > 0
                Base::App.logger.log_string "Cleaned up #{cleaned_count} closed connections"
              end
            rescue ex
              Base::App.logger.log_string "Connection cleanup error: #{ex.message}"
            end
          end
        end
      end
      
      private def self.instance
        @@instance ||= new(__FILE__)
      end
      
      # Enhanced serve method with realtime support
      def serve(port=8080, host="0.0.0.0", workers : Int32 = System.cpu_count)
        @port = port.to_i
        
        run_string = <<-RUN_STR
        [Amethyst #{VERSION}] serving realtime application "#{@name}" at #{@enable_http2 ? "https" : "http"}://#{host}:#{@port}
        Realtime features: WebSocket ✅ SSE ✅ Broadcasting ✅ Connection Management ✅
        RUN_STR
        
        App.logger.log_string run_string
        
        if workers > 1
          serve_multi_threaded(host, port, workers)
        else
          serve_single_threaded(host, port)
        end
      end
      
      # Realtime-specific health check
      def self.realtime_health_check(path : String = "/realtime/health")
        get path, "RealtimeHealthController", "check"
      end
      
      # Realtime metrics endpoint
      def self.realtime_metrics(path : String = "/realtime/metrics")
        get path, "RealtimeMetricsController", "show"
      end
    end
  end
  
  # Enhanced controllers for realtime health and metrics
  class RealtimeHealthController < ::Amethyst::Controller
    def check
      app_instance = Base::RealtimeApp.send(:instance)
      stats = app_instance.realtime_stats
      
      health_status = {
        status: "healthy",
        timestamp: Time.utc.to_rfc3339,
        realtime: {
          websocket_connections: stats.dig(:unified_manager, :websocket, :active_connections),
          sse_connections: stats.dig(:unified_manager, :sse, :active_connections),
          total_connections: stats.dig(:unified_manager, :total_connections),
          channels: stats.dig(:unified_manager, :websocket, :channels),
          routes: {
            websocket: stats.dig(:routes, :websocket_routes).try(&.as(Array).size) || 0,
            sse: stats.dig(:routes, :sse_routes).try(&.as(Array).size) || 0
          }
        }
      }
      
      response.content_type = "application/json"
      response.headers["Cache-Control"] = "no-cache"
      health_status.to_json
    end
  end
  
  class RealtimeMetricsController < ::Amethyst::Controller
    def show
      app_instance = Base::RealtimeApp.send(:instance)
      metrics = app_instance.realtime_stats
      
      response.content_type = "application/json"
      response.headers["Cache-Control"] = "no-cache"
      metrics.to_json
    end
  end
end