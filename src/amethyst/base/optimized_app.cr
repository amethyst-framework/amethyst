require "./app"
require "../routing/optimized_router"
require "../routing/radix_tree"
require "../middleware/zero_copy_static"
require "../middleware/cache"
require "./connection_pool"
require "../http/http2_server"

module Amethyst
  module Base
    class OptimizedApp < App
      @optimized_router : Routing::OptimizedRouter
      @http2_server : Http::Http2Server?
      @connection_pool : Base::HttpConnectionPool
      @response_cache : Middleware::ResponseCache
      @enable_http2 : Bool
      @enable_caching : Bool
      
      def initialize(app_path, app_type={{@type.name.stringify}}, 
                     enable_http2 : Bool = true,
                     enable_caching : Bool = true,
                     cache_size : Int64 = 100_000_000)
        super(app_path, app_type)
        
        @enable_http2 = enable_http2
        @enable_caching = enable_caching
        @optimized_router = Routing::OptimizedRouter.new
        @connection_pool = Base::HttpConnectionPool.new(25, 30.seconds)
        @response_cache = Middleware::ResponseCache.new(nil, Middleware::MemoryCache.new(cache_size))
        
        setup_optimized_middleware
        setup_optimized_routing
        
        if @enable_http2
          @http2_server = Http::Http2Server.new(@http_handler)
        end
      end
      
      private def setup_optimized_middleware
        # Clear default middleware and add optimized versions
        self.class.middleware.clear
        
        # Exception handling (keep at top)
        self.class.use Middleware::ShowExceptions
        
        # Caching middleware
        if @enable_caching
          self.class.use Middleware::ETagCache
          self.class.use Middleware::ConditionalGet
          self.class.use @response_cache
        end
        
        # Development middleware
        if self.class.settings.environment == "development"
          self.class.use Middleware::HttpLogger
          self.class.use Middleware::TimeLogger
        end
        
        # Session middleware
        self.class.use Middleware::Session
        
        # Zero-copy static file serving
        self.class.use Middleware::Static
        
        # Build optimized middleware stack
        @app = Middleware::MiddlewareStack.instance.build_middleware
        @http_handler = Base::Handler.new(@app)
      end
      
      private def setup_optimized_routing
        # Migrate existing routes to optimized router
        migrate_legacy_routes
        
        # Compile routes for optimal performance
        @optimized_router.compile!
      end
      
      def serve(port=8080, host="0.0.0.0", workers : Int32 = System.cpu_count)
        @port = port.to_i
        
        run_string = "[Amethyst #{VERSION}] serving optimized application \"#{@name}\" at #{@enable_http2 ? "https" : "http"}://#{host}:#{@port}"
        App.logger.log_string run_string
        
        if workers > 1
          serve_multi_threaded(host, port, workers)
        else
          serve_single_threaded(host, port)
        end
      end
      
      private def serve_single_threaded(host : String, port : Int32)
        if @enable_http2 && @http2_server
          server = OpenSSL::SSL::Server.new(::HTTP::Server.new([@http_handler]))
          # Configure SSL context for HTTP/2
          context = server.context
          context.alpn_protocol = "h2"
          server.bind_tcp(host, port)
        else
          server = ::HTTP::Server.new([@http_handler])
          server.bind_tcp(host, port)
        end
        
        server.listen
      end
      
      private def serve_multi_threaded(host : String, port : Int32, workers : Int32)
        # Create worker processes/threads
        workers.times do |i|
          spawn do
            worker_server = ::HTTP::Server.new([Base::Handler.new(@app)])
            worker_server.bind_tcp(host, port + i)
            
            App.logger.log_string "Worker #{i} listening on #{host}:#{port + i}"
            worker_server.listen
          end
        end
        
        # Keep main thread alive
        sleep
      end
      
      # Override routing methods to use optimized router
      def self.get(path : String, controller : String, action : String)
        route = Routing::Route.new("GET", path, controller, action)
        instance.@optimized_router.add_route("GET", path, route)
      end
      
      def self.post(path : String, controller : String, action : String)
        route = Routing::Route.new("POST", path, controller, action)
        instance.@optimized_router.add_route("POST", path, route)
      end
      
      def self.put(path : String, controller : String, action : String)
        route = Routing::Route.new("PUT", path, controller, action)
        instance.@optimized_router.add_route("PUT", path, route)
      end
      
      def self.delete(path : String, controller : String, action : String)
        route = Routing::Route.new("DELETE", path, controller, action)
        instance.@optimized_router.add_route("DELETE", path, route)
      end
      
      def self.patch(path : String, controller : String, action : String)
        route = Routing::Route.new("PATCH", path, controller, action)
        instance.@optimized_router.add_route("PATCH", path, route)
      end
      
      def self.options(path : String, controller : String, action : String)
        route = Routing::Route.new("OPTIONS", path, controller, action)
        instance.@optimized_router.add_route("OPTIONS", path, route)
      end
      
      def self.head(path : String, controller : String, action : String)
        route = Routing::Route.new("HEAD", path, controller, action)
        instance.@optimized_router.add_route("HEAD", path, route)
      end
      
      # Resource routing with parameters
      def self.resource(name : String, controller : String? = nil)
        controller_name = controller || "#{name.capitalize}Controller"
        
        get "/#{name}", controller_name, "index"
        get "/#{name}/new", controller_name, "new"
        post "/#{name}", controller_name, "create"
        get "/#{name}/:id", controller_name, "show"
        get "/#{name}/:id/edit", controller_name, "edit"
        put "/#{name}/:id", controller_name, "update"
        patch "/#{name}/:id", controller_name, "update"
        delete "/#{name}/:id", controller_name, "destroy"
      end
      
      # Namespace routing
      def self.namespace(name : String, &block)
        with OptimizedNamespace.new(name, instance) yield
      end
      
      def find_route(request : Http::Request) : {route: Routing::Route?, params: Hash(String, String)}
        @optimized_router.find_route(request.method, request.path)
      end
      
      def stats
        {
          router: @optimized_router.stats,
          cache: @enable_caching ? @response_cache.cache_stats : nil,
          connections: @connection_pool.stats,
          http2_enabled: @enable_http2
        }
      end
      
      def clear_caches
        @optimized_router.clear_cache
        @response_cache.clear_cache if @enable_caching
      end
      
      # Health check endpoint
      def self.health_check(path : String = "/health")
        get path, "HealthController", "check"
      end
      
      # Metrics endpoint  
      def self.metrics(path : String = "/metrics")
        get path, "MetricsController", "show"
      end
      
      private def migrate_legacy_routes
        # Legacy route support removed - no migration needed
      end
      
      private def self.instance
        @@instance ||= new(__FILE__)
      end
      
      class OptimizedNamespace
        def initialize(@prefix : String, @app : OptimizedApp)
        end
        
        def get(path : String, controller : String, action : String)
          full_path = "/#{@prefix}#{path}".gsub("//", "/")
          @app.class.get(full_path, controller, action)
        end
        
        def post(path : String, controller : String, action : String)
          full_path = "/#{@prefix}#{path}".gsub("//", "/")
          @app.class.post(full_path, controller, action)
        end
        
        def put(path : String, controller : String, action : String)
          full_path = "/#{@prefix}#{path}".gsub("//", "/")
          @app.class.put(full_path, controller, action)
        end
        
        def delete(path : String, controller : String, action : String)
          full_path = "/#{@prefix}#{path}".gsub("//", "/")
          @app.class.delete(full_path, controller, action)
        end
        
        def patch(path : String, controller : String, action : String)
          full_path = "/#{@prefix}#{path}".gsub("//", "/")
          @app.class.patch(full_path, controller, action)
        end
        
        def resource(name : String, controller : String? = nil)
          @app.class.resource("#{@prefix}/#{name}", controller)
        end
      end
    end
  end
end