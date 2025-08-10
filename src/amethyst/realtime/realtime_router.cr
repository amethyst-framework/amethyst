require "../websocket/websocket"
require "../sse/server_sent_events"

module Amethyst
  module Realtime
    # Enhanced router with WebSocket and SSE support
    class RealtimeRouter
      @@instance : RealtimeRouter?
      
      @websocket_handler : WebSocket::WebSocketHandler
      @sse_handler : SSE::SSEHandler
      @websocket_routes : Hash(String, Hash(Symbol, String | WebSocket::Controller.class))
      @sse_routes : Hash(String, Hash(Symbol, String | SSE::Controller.class))
      @route_groups : Hash(String, RouteGroup)
      
      def self.instance
        @@instance ||= new
      end
      
      def initialize
        @websocket_handler = WebSocket::WebSocketHandler.new
        @sse_handler = SSE::SSEHandler.new
        @websocket_routes = Hash(String, Hash(Symbol, String | WebSocket::Controller.class)).new
        @sse_routes = Hash(String, Hash(Symbol, String | SSE::Controller.class)).new
        @route_groups = Hash(String, RouteGroup).new
      end
      
      def websocket(path : String, controller : WebSocket::Controller.class, **options)
        route_info = {
          :controller => controller,
          :path => path,
          :middleware => options[:middleware]?.try(&.as(Array(Middleware::Base.class))) || [] of Middleware::Base.class,
          :auth => options[:auth]?.try(&.as(Bool)) || false,
          :rate_limit => options[:rate_limit]?.try(&.as(Hash(Symbol, Int32))) || {} of Symbol => Int32,
          :cors => options[:cors]?.try(&.as(Bool)) || true
        }
        
        @websocket_routes[path] = route_info
        @websocket_handler.add_websocket_route(path, controller)
        
        Base::App.logger.log_string "WebSocket route added: #{path} -> #{controller}"
      end
      
      def websocket(path : String, &handler : WebSocket::Connection -> Nil)
        route_info = {
          :handler => handler,
          :path => path,
          :middleware => [] of Middleware::Base.class,
          :auth => false,
          :rate_limit => {} of Symbol => Int32,
          :cors => true
        }
        
        @websocket_routes[path] = route_info
        @websocket_handler.add_websocket_route(path, &handler)
        
        Base::App.logger.log_string "WebSocket route added: #{path} (block handler)"
      end
      
      def sse(path : String, controller : SSE::Controller.class, **options)
        route_info = {
          :controller => controller,
          :path => path,
          :middleware => options[:middleware]?.try(&.as(Array(Middleware::Base.class))) || [] of Middleware::Base.class,
          :auth => options[:auth]?.try(&.as(Bool)) || false,
          :rate_limit => options[:rate_limit]?.try(&.as(Hash(Symbol, Int32))) || {} of Symbol => Int32,
          :cors => options[:cors]?.try(&.as(Bool)) || true,
          :history_size => options[:history_size]?.try(&.as(Int32)) || 100
        }
        
        @sse_routes[path] = route_info
        @sse_handler.add_sse_route(path, controller)
        
        Base::App.logger.log_string "SSE route added: #{path} -> #{controller}"
      end
      
      def sse(path : String, &handler : SSE::Connection -> Nil)
        route_info = {
          :handler => handler,
          :path => path,
          :middleware => [] of Middleware::Base.class,
          :auth => false,
          :rate_limit => {} of Symbol => Int32,
          :cors => true,
          :history_size => 100
        }
        
        @sse_routes[path] = route_info
        @sse_handler.add_sse_route(path, &handler)
        
        Base::App.logger.log_string "SSE route added: #{path} (block handler)"
      end
      
      def group(prefix : String, **options, &block)
        group = RouteGroup.new(prefix, self, options)
        @route_groups[prefix] = group
        
        with group yield group
      end
      
      def namespace(name : String, &block)
        group("/#{name}", &block)
      end
      
      def channel(name : String, &block)
        channel_group = ChannelGroup.new(name, self)
        with channel_group yield channel_group
      end
      
      def get_websocket_handler : WebSocket::WebSocketHandler
        @websocket_handler
      end
      
      def get_sse_handler : SSE::SSEHandler
        @sse_handler
      end
      
      def routes_info
        {
          websocket_routes: @websocket_routes.keys,
          sse_routes: @sse_routes.keys,
          route_groups: @route_groups.keys
        }
      end
      
      def stats
        {
          websocket_connections: WebSocket::ConnectionManager.instance.stats,
          sse_connections: SSE::ConnectionManager.instance.stats,
          total_routes: @websocket_routes.size + @sse_routes.size
        }
      end
      
      class RouteGroup
        @prefix : String
        @router : RealtimeRouter
        @options : Hash(Symbol, String | Int32 | Bool)
        
        def initialize(@prefix : String, @router : RealtimeRouter, @options : Hash(Symbol, String | Int32 | Bool))
        end
        
        def websocket(path : String, controller : WebSocket::Controller.class, **options)
          full_path = normalize_path(@prefix + path)
          merged_options = @options.merge(options.to_h)
          @router.websocket(full_path, controller, **merged_options)
        end
        
        def websocket(path : String, &handler : WebSocket::Connection -> Nil)
          full_path = normalize_path(@prefix + path)
          @router.websocket(full_path, &handler)
        end
        
        def sse(path : String, controller : SSE::Controller.class, **options)
          full_path = normalize_path(@prefix + path)
          merged_options = @options.merge(options.to_h)
          @router.sse(full_path, controller, **merged_options)
        end
        
        def sse(path : String, &handler : SSE::Connection -> Nil)
          full_path = normalize_path(@prefix + path)
          @router.sse(full_path, &handler)
        end
        
        def group(prefix : String, **options, &block)
          full_prefix = normalize_path(@prefix + prefix)
          merged_options = @options.merge(options.to_h)
          @router.group(full_prefix, **merged_options, &block)
        end
        
        private def normalize_path(path : String) : String
          path.gsub(/\/+/, "/").chomp("/")
        end
      end
      
      class ChannelGroup
        @name : String
        @router : RealtimeRouter
        
        def initialize(@name : String, @router : RealtimeRouter)
        end
        
        def websocket(path : String, controller : WebSocket::Controller.class, **options)
          full_path = "/channels/#{@name}#{path}"
          @router.websocket(full_path, controller, **options)
        end
        
        def sse(path : String, controller : SSE::Controller.class, **options)
          full_path = "/channels/#{@name}#{path}"
          @router.sse(full_path, controller, **options)
        end
        
        def broadcast(data : Hash | Array | String, event : String? = nil, id : String? = nil)
          WebSocket::ConnectionManager.instance.broadcast_to_channel(@name, data)
          SSE::ConnectionManager.instance.broadcast_to_channel(@name, data, event, id)
        end
        
        def stats
          {
            websocket_connections: WebSocket::ConnectionManager.instance.stats,
            sse_connections: SSE::ConnectionManager.instance.stats
          }
        end
      end
    end
    
    # Realtime middleware that handles both WebSocket and SSE
    class RealtimeMiddleware < Middleware::Base
      @realtime_router : RealtimeRouter
      @websocket_handler : WebSocket::WebSocketHandler
      @sse_handler : SSE::SSEHandler
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @realtime_router = RealtimeRouter.instance
        @websocket_handler = @realtime_router.get_websocket_handler
        @sse_handler = @realtime_router.get_sse_handler
      end
      
      def call(request) : Http::Response
        # Check if it's a WebSocket upgrade request
        if websocket_request?(request)
          return @websocket_handler.call(request)
        end
        
        # Check if it's an SSE request
        if sse_request?(request)
          return @sse_handler.call(request)
        end
        
        # Regular HTTP request
        @app.call(request)
      end
      
      private def websocket_request?(request : Http::Request) : Bool
        connection_header = request.headers["Connection"]?
        upgrade_header = request.headers["Upgrade"]?
        
        connection_header.try(&.downcase.includes?("upgrade")) &&
        upgrade_header.try(&.downcase) == "websocket"
      end
      
      private def sse_request?(request : Http::Request) : Bool
        accept_header = request.headers["Accept"]?
        accept_header.try(&.includes?("text/event-stream")) || false
      end
    end
    
    # Enhanced connection manager for both WebSocket and SSE
    class UnifiedConnectionManager
      @@instance : UnifiedConnectionManager?
      
      @websocket_manager : WebSocket::ConnectionManager
      @sse_manager : SSE::ConnectionManager
      @cross_protocol_channels : Hash(String, Set(String))
      @mutex : Mutex
      
      def initialize
        @websocket_manager = WebSocket::ConnectionManager.instance
        @sse_manager = SSE::ConnectionManager.instance
        @cross_protocol_channels = Hash(String, Set(String)).new
        @mutex = Mutex.new
      end
      
      def self.instance
        @@instance ||= new
      end
      
      def broadcast_to_channel(channel : String, data : Hash | Array | String, 
                              event : String? = nil, id : String? = nil)
        # Broadcast to both WebSocket and SSE connections
        @websocket_manager.broadcast_to_channel(channel, data)
        @sse_manager.broadcast_to_channel(channel, data, event, id)
      end
      
      def broadcast_to_all(data : Hash | Array | String, event : String? = nil, id : String? = nil)
        @websocket_manager.broadcast_to_all(data)
        @sse_manager.broadcast_to_all(data, event, id)
      end
      
      def create_cross_protocol_channel(channel : String)
        @mutex.synchronize do
          @cross_protocol_channels[channel] = Set(String).new
        end
      end
      
      def stats
        {
          websocket: @websocket_manager.stats,
          sse: @sse_manager.stats,
          cross_protocol_channels: @cross_protocol_channels.size,
          total_connections: total_active_connections
        }
      end
      
      def cleanup_all_connections
        websocket_cleaned = @websocket_manager.cleanup_closed_connections
        sse_cleaned = @sse_manager.cleanup_closed_connections
        
        websocket_cleaned + sse_cleaned
      end
      
      private def total_active_connections
        ws_stats = @websocket_manager.stats
        sse_stats = @sse_manager.stats
        
        ws_active = ws_stats[:active_connections]?.try(&.as(Int32)) || 0
        sse_active = sse_stats[:active_connections]?.try(&.as(Int32)) || 0
        
        ws_active + sse_active
      end
    end
    
    # Realtime authentication middleware
    class RealtimeAuth < Middleware::Base
      @auth_handler : Proc(Http::Request, Bool)
      @token_extractor : Proc(Http::Request, String?)
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @auth_handler = ->(req : Http::Request) { true }
        @token_extractor = ->(req : Http::Request) { 
          req.headers["Authorization"]?.try(&.gsub("Bearer ", ""))
        }
      end
      
      def call(request) : Http::Response
        if realtime_request?(request)
          unless @auth_handler.call(request)
            return Http::Response.new(401, "Unauthorized")
          end
        end
        
        @app.call(request)
      end
      
      private def realtime_request?(request : Http::Request) : Bool
        websocket_request?(request) || sse_request?(request)
      end
      
      private def websocket_request?(request : Http::Request) : Bool
        connection_header = request.headers["Connection"]?
        upgrade_header = request.headers["Upgrade"]?
        
        connection_header.try(&.downcase.includes?("upgrade")) &&
        upgrade_header.try(&.downcase) == "websocket"
      end
      
      private def sse_request?(request : Http::Request) : Bool
        accept_header = request.headers["Accept"]?
        accept_header.try(&.includes?("text/event-stream")) || false
      end
    end
    
    # Rate limiting for realtime connections
    class RealtimeRateLimit < Middleware::Base
      @rate_limits : Hash(String, Hash(Symbol, Int32))
      @connection_counts : Hash(String, Hash(Symbol, Int32))
      @last_reset : Time
      @reset_interval : Time::Span
      @mutex : Mutex
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @rate_limits = {"default" => {:connections => 100, :messages => 1000}}
        @reset_interval = 1.minute
        @connection_counts = Hash(String, Hash(Symbol, Int32)).new
        @last_reset = Time.utc
        @mutex = Mutex.new
      end
      
      def call(request) : Http::Response
        if realtime_request?(request)
          client_id = extract_client_id(request)
          
          unless check_rate_limit(client_id, :connections)
            return Http::Response.new(429, "Rate limit exceeded")
          end
          
          increment_count(client_id, :connections)
        end
        
        @app.call(request)
      end
      
      def check_message_rate_limit(client_id : String) : Bool
        check_rate_limit(client_id, :messages)
      end
      
      def increment_message_count(client_id : String)
        increment_count(client_id, :messages)
      end
      
      private def realtime_request?(request : Http::Request) : Bool
        websocket_request?(request) || sse_request?(request)
      end
      
      private def websocket_request?(request : Http::Request) : Bool
        connection_header = request.headers["Connection"]?
        upgrade_header = request.headers["Upgrade"]?
        
        connection_header.try(&.downcase.includes?("upgrade")) &&
        upgrade_header.try(&.downcase) == "websocket"
      end
      
      private def sse_request?(request : Http::Request) : Bool
        accept_header = request.headers["Accept"]?
        accept_header.try(&.includes?("text/event-stream")) || false
      end
      
      private def extract_client_id(request : Http::Request) : String
        # Extract client ID from IP, auth token, or other identifier
        request.headers["X-Real-IP"]? || 
        request.headers["X-Forwarded-For"]?.try(&.split(",").first.strip) ||
        "unknown"
      end
      
      private def check_rate_limit(client_id : String, metric : Symbol) : Bool
        @mutex.synchronize do
          reset_counts_if_needed
          
          limits = @rate_limits["default"] || {:connections => 100, :messages => 1000}
          current_count = @connection_counts[client_id]?.try(&.[metric]?) || 0
          limit = limits[metric]? || 100
          
          current_count < limit
        end
      end
      
      private def increment_count(client_id : String, metric : Symbol)
        @mutex.synchronize do
          @connection_counts[client_id] ||= Hash(Symbol, Int32).new
          @connection_counts[client_id][metric] = (@connection_counts[client_id][metric]? || 0) + 1
        end
      end
      
      private def reset_counts_if_needed
        if Time.utc - @last_reset > @reset_interval
          @connection_counts.clear
          @last_reset = Time.utc
        end
      end
    end
  end
end