require "./config/**"
require "./base/app"
require "./routing/**"
require "./routing/action_route"
require "./controller"
require "./controller_dispatcher"
require "./controllers/health_controller"
require "./controllers/metrics_controller"
require "./middleware/metrics_middleware"

module Amethyst
  # Modern, user-friendly application builder
  class Application
    @app : Base::App
    @security_config : Config::SecurityConfig
    @performance_config : Config::PerformanceConfig
    @realtime_config : Config::RealtimeConfig
    @observability_config : Config::ObservabilityConfig
    @router : Routing::OptimizedRouter
    @routes : Array(Routing::BaseRoute)
    
    def initialize(environment : String = ENV["AMETHYST_ENV"]? || "development")
      @app = Base::App.new(__FILE__)
      # Use the singleton router that's already integrated with the middleware chain
      @router = Routing::OptimizedRouter.instance
      @routes = [] of Routing::BaseRoute
      
      # Register built-in controllers
      register_built_in_controllers
      
      # Initialize configurations based on environment
      @security_config = case environment
      when "development" then Config::SecurityConfig.development
      when "production"  then Config::SecurityConfig.production  
      when "test"        then Config::SecurityConfig.testing
      else                    Config::SecurityConfig.new
      end
      
      @performance_config = case environment
      when "development" then Config::PerformanceConfig.development
      when "production"  then Config::PerformanceConfig.production
      when "test"        then Config::PerformanceConfig.testing
      else                    Config::PerformanceConfig.new
      end
      
      @realtime_config = case environment
      when "development" then Config::RealtimeConfig.development
      when "production"  then Config::RealtimeConfig.production
      when "test"        then Config::RealtimeConfig.testing
      else                    Config::RealtimeConfig.new
      end
      
      @observability_config = case environment
      when "development" then Config::ObservabilityConfig.development
      when "production"  then Config::ObservabilityConfig.production
      when "test"        then Config::ObservabilityConfig.testing
      else                    Config::ObservabilityConfig.new
      end
    end
    
    # Fluent security configuration
    def security(&block : Config::SecurityConfig -> Nil)
      block.call(@security_config)
      self
    end
    
    # Fluent performance configuration  
    def performance(&block : Config::PerformanceConfig -> Nil)
      block.call(@performance_config)
      self
    end
    
    # Fluent realtime configuration
    def realtime(&block : Config::RealtimeConfig -> Nil)
      block.call(@realtime_config)
      self
    end
    
    # Fluent observability configuration
    def observability(&block : Config::ObservabilityConfig -> Nil)
      block.call(@observability_config)
      self
    end
    
    # Quick configuration methods
    def with_security(config : Config::SecurityConfig? = nil)
      @security_config = config if config
      self
    end
    
    def with_performance(config : Config::PerformanceConfig? = nil)
      @performance_config = config if config
      self
    end
    
    def with_realtime(config : Config::RealtimeConfig? = nil)
      @realtime_config = config if config
      self
    end
    
    def with_observability(config : Config::ObservabilityConfig? = nil)
      @observability_config = config if config
      self
    end
    
    # Routing DSL (Fully implemented)
    def get(path : String, controller : String, action : String)
      add_route("GET", path, controller, action)
      self
    end
    
    def post(path : String, controller : String, action : String)
      add_route("POST", path, controller, action)
      self
    end
    
    def put(path : String, controller : String, action : String)
      add_route("PUT", path, controller, action)
      self
    end
    
    def delete(path : String, controller : String, action : String)
      add_route("DELETE", path, controller, action)
      self
    end
    
    def patch(path : String, controller : String, action : String)
      add_route("PATCH", path, controller, action)
      self
    end
    
    def options(path : String, controller : String, action : String)
      add_route("OPTIONS", path, controller, action)
      self
    end
    
    def head(path : String, controller : String, action : String)
      add_route("HEAD", path, controller, action)
      self
    end
    
    # RESTful resource routing
    def resource(name : String, controller : String? = nil)
      controller_name = controller || "#{name.capitalize}Controller"
      base_path = "/#{name}"
      
      get("#{base_path}", controller_name, "index")
      get("#{base_path}/new", controller_name, "new")
      post("#{base_path}", controller_name, "create")
      get("#{base_path}/:id", controller_name, "show")
      get("#{base_path}/:id/edit", controller_name, "edit")
      put("#{base_path}/:id", controller_name, "update")
      patch("#{base_path}/:id", controller_name, "update")
      delete("#{base_path}/:id", controller_name, "destroy")
      
      self
    end
    
    def resources(name : String, controller : String? = nil, &block)
      resource(name, controller)
      # TODO: Implement nested resources support with block
      self
    end
    
    # Namespace routing
    def namespace(name : String, &block)
      # TODO: Implement namespace routing with builder pattern
      # This would create a new ApplicationNamespace that prefixes paths
      self
    end
    
    # WebSocket routing (simplified for now)
    def websocket(path : String, controller : String)
      # Create a special WebSocket route
      add_websocket_route(path, controller)
      self
    end
    
    # Server-Sent Events routing (simplified for now)
    def server_sent_events(path : String, controller : String)
      # Create a special SSE route
      add_sse_route(path, controller)
      self
    end
    
    # Build and configure the application
    def build!
      setup_middleware
      setup_health_checks
      setup_metrics_endpoints
      register_routes
      compile_routes
      @app
    end
    
    # Start the server
    def serve(port : Int32 = 8080, host : String = "0.0.0.0")
      build!
      @app.serve(port)
    end
    
    # Start the server and bind to address
    def listen(port : Int32 = 8080, host : String = "0.0.0.0")
      serve(port, host)
    end
    
    # Route management methods
    private def add_route(method : String, path : String, controller : String, action : String)
      route = Routing::ActionRoute.new(method, path, controller, action)
      @routes << route
    end
    
    private def add_websocket_route(path : String, controller : String)
      # WebSocket routes are handled differently - add to special collection
      # For now, create a regular route that handles WebSocket upgrade
      route = Routing::ActionRoute.new("GET", path, controller, "websocket_upgrade")
      @routes << route
    end
    
    private def add_sse_route(path : String, controller : String)
      # SSE routes are GET requests with special content-type
      route = Routing::ActionRoute.new("GET", path, controller, "sse_stream")
      @routes << route
    end
    
    private def register_routes
      @routes.each do |route|
        @router.add_route(route.method, route.path, route)
      end
    end
    
    private def compile_routes
      @router.compile! if @performance_config.compiled_routes
    end
    
    private def setup_health_checks
      if @observability_config.health_checks_enabled
        # Add health check endpoint
        get(@observability_config.health_endpoint, "HealthController", "check")
      end
    end
    
    private def setup_metrics_endpoints  
      if @observability_config.metrics_enabled
        # Add metrics endpoint
        get(@observability_config.metrics_endpoint, "MetricsController", "show")
      end
    end
    
    private def register_built_in_controllers
      ControllerDispatcher.instance.register_controller("HealthController", HealthController)
      ControllerDispatcher.instance.register_controller("MetricsController", MetricsController)
    end
    
    private def setup_middleware
      # Clear any existing middleware
      @app.class.middleware.clear
      
      # Add middleware in the correct order
      add_observability_middleware if @observability_config.logging_enabled || 
                                        @observability_config.tracing_enabled ||
                                        @observability_config.metrics_enabled
      
      add_security_middleware if @security_config.csrf_enabled ||
                               @security_config.xss_enabled ||
                               @security_config.rate_limiting_enabled ||
                               @security_config.secure_headers_enabled
      
      add_performance_middleware if @performance_config.caching_enabled ||
                                  @performance_config.connection_pool_enabled
      
      add_realtime_middleware if @realtime_config.websockets_enabled ||
                               @realtime_config.sse_enabled
      
      # Always add basic middleware
      add_basic_middleware
    end
    
    private def add_observability_middleware
      # Add structured logging
      if @observability_config.logging_enabled
        # Only add if the middleware classes exist
        begin
          @app.class.use Observability::CorrelationMiddleware
        rescue
          # Middleware not available
        end
        begin
          @app.class.use Observability::RequestLogger
        rescue
          # Middleware not available
        end
      end
      
      # Add distributed tracing
      if @observability_config.tracing_enabled
        begin
          @app.class.use Observability::TracingMiddleware
        rescue
          # Middleware not available
        end
      end
      
      # Add metrics middleware
      if @observability_config.metrics_enabled
        metrics_middleware = Middleware::MetricsMiddleware.new(nil)
        Middleware::MetricsMiddleware.instance = metrics_middleware
        @app.class.use metrics_middleware.class
      end
    end
    
    private def add_security_middleware
      # Add security middleware with error handling
      if @security_config.secure_headers_enabled
        begin
          @app.class.use Security::SecureHeaders
        rescue
          # Security::SecureHeaders not available
        end
      end
      
      if @security_config.csrf_enabled
        begin
          @app.class.use Security::CSRFProtection
        rescue
          # Security::CSRFProtection not available
        end
      end
      
      if @security_config.xss_enabled
        begin
          @app.class.use Security::XSSProtection
        rescue
          # Security::XSSProtection not available
        end
      end
      
      if @security_config.sql_injection_enabled
        begin
          @app.class.use Security::SQLInjectionProtection
        rescue
          # Security::SQLInjectionProtection not available
        end
      end
      
      if @security_config.rate_limiting_enabled
        begin
          @app.class.use Security::RateLimitMiddleware
        rescue
          # Security::RateLimitMiddleware not available
        end
      end
      
      if @security_config.jwt_enabled
        begin
          @app.class.use Security::JWTAuthentication
        rescue
          # Security::JWTAuthentication not available
        end
      end
    end
    
    private def add_performance_middleware
      # Add caching middleware
      if @performance_config.caching_enabled
        if @performance_config.etag_enabled
          @app.class.use Middleware::ETagCache
        end
        
        if @performance_config.conditional_get_enabled
          @app.class.use Middleware::ConditionalGet
        end
        
        @app.class.use Middleware::ResponseCache
      end
    end
    
    private def add_realtime_middleware
      if @realtime_config.websockets_enabled || @realtime_config.sse_enabled
        begin
          @app.class.use Realtime::RealtimeMiddleware
        rescue
          # Realtime::RealtimeMiddleware not available
        end
        
        if @realtime_config.realtime_auth_enabled
          begin
            @app.class.use Realtime::RealtimeAuth
          rescue
            # Realtime::RealtimeAuth not available
          end
        end
        
        if @realtime_config.realtime_rate_limiting
          begin
            @app.class.use Realtime::RealtimeRateLimit
          rescue
            # Realtime::RealtimeRateLimit not available
          end
        end
      end
    end
    
    private def add_basic_middleware
      # Only add middleware that we know exists and works
      
      # Static file serving (only use what exists)
      if @performance_config.static_file_serving
        begin
          if @performance_config.zero_copy_enabled
            @app.class.use Middleware::ZeroCopyStatic
          else
            @app.class.use Middleware::Static
          end
        rescue
          # Static middleware not available
        end
      end
      
      # Note: Other basic middleware (ShowExceptions, HttpLogger, TimeLogger, Session)
      # may not be available in this version of Amethyst. The modern Application
      # builder provides a clean starting point where apps can add specific middleware
      # as needed. Essential functionality like exception handling should be
      # implemented at the application/controller level.
    end
  end
end