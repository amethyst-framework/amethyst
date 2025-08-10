require "./config/**"
require "./base/app"

module Amethyst
  # Modern, user-friendly application builder
  class Application
    @app : Base::App
    @security_config : Config::SecurityConfig
    @performance_config : Config::PerformanceConfig
    @realtime_config : Config::RealtimeConfig
    @observability_config : Config::ObservabilityConfig
    
    def initialize(environment : String = ENV["AMETHYST_ENV"]? || "development")
      @app = Base::App.new(__FILE__)
      
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
    
    # Routing DSL (Modern implementation - TODO: Complete integration)
    def get(path : String, controller : String, action : String)
      # TODO: Store routes internally and integrate with routing system
      # For now, just return self to maintain fluent interface
      self
    end
    
    def post(path : String, controller : String, action : String)
      # TODO: Store routes internally and integrate with routing system
      self
    end
    
    def put(path : String, controller : String, action : String)
      # TODO: Store routes internally and integrate with routing system
      self
    end
    
    def delete(path : String, controller : String, action : String)
      # TODO: Store routes internally and integrate with routing system
      self
    end
    
    def patch(path : String, controller : String, action : String)
      # TODO: Store routes internally and integrate with routing system
      self
    end
    
    def options(path : String, controller : String, action : String)
      # TODO: Store routes internally and integrate with routing system
      self
    end
    
    def head(path : String, controller : String, action : String)
      # TODO: Store routes internally and integrate with routing system
      self
    end
    
    # RESTful resource routing
    def resource(name : String, controller : String? = nil)
      # TODO: Generate RESTful routes
      self
    end
    
    def resources(name : String, controller : String? = nil, &block)
      # TODO: Implement nested resources
      self
    end
    
    # Namespace routing
    def namespace(name : String, &block)
      # TODO: Implement namespace routing with builder pattern
      self
    end
    
    # WebSocket routing
    def websocket(path : String, controller : WebSocket::Controller.class)
      # TODO: Setup WebSocket routing
      self
    end
    
    # Server-Sent Events routing
    def server_sent_events(path : String, controller : SSE::Controller.class)
      # TODO: Setup SSE routing
      self
    end
    
    # Build and configure the application
    def build!
      setup_middleware
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
    
    private def setup_middleware
      # Clear any existing middleware
      @app.class.middleware.clear
      
      # Add core middleware in the right order
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
        @app.class.use Observability::CorrelationMiddleware.new(nil)
        @app.class.use Observability::RequestLogger.new(nil)
      end
      
      # Add distributed tracing
      if @observability_config.tracing_enabled
        @app.class.use Observability::TracingMiddleware.new(nil)
      end
      
      # Add metrics collection
      if @observability_config.metrics_enabled
        # TODO: Add metrics middleware when available
      end
      
      # Add health checks
      if @observability_config.health_checks_enabled
        # TODO: Add health check routes
      end
    end
    
    private def add_security_middleware
      # Add security headers first
      if @security_config.secure_headers_enabled
        @app.class.use Security::SecureHeaders.new(nil)
      end
      
      # Add CSRF protection
      if @security_config.csrf_enabled
        @app.class.use Security::CSRFProtection.with_config(@security_config)
      end
      
      # Add XSS protection
      if @security_config.xss_enabled
        @app.class.use Security::XSSProtection.new(nil)
      end
      
      # Add SQL injection protection
      if @security_config.sql_injection_enabled
        @app.class.use Security::SQLInjectionProtection.new(nil)
      end
      
      # Add rate limiting
      if @security_config.rate_limiting_enabled
        @app.class.use Security::RateLimitMiddleware.new(nil)
      end
      
      # Add JWT authentication if enabled
      if @security_config.jwt_enabled
        @app.class.use Security::JWTAuthentication.new(nil)
      end
    end
    
    private def add_performance_middleware
      # Add caching middleware
      if @performance_config.caching_enabled
        if @performance_config.etag_enabled
          @app.class.use Middleware::ETagCache.new(nil)
        end
        
        if @performance_config.conditional_get_enabled
          @app.class.use Middleware::ConditionalGet.new(nil)
        end
        
        @app.class.use Middleware::ResponseCache.new(nil)
      end
    end
    
    private def add_realtime_middleware
      if @realtime_config.websockets_enabled || @realtime_config.sse_enabled
        @app.class.use Realtime::RealtimeMiddleware.new(nil)
        
        if @realtime_config.realtime_auth_enabled
          @app.class.use Realtime::RealtimeAuth.new(nil)
        end
        
        if @realtime_config.realtime_rate_limiting
          @app.class.use Realtime::RealtimeRateLimit.new(nil)
        end
      end
    end
    
    private def add_basic_middleware
      # Exception handling (should be first)
      @app.class.use Middleware::ShowExceptions
      
      # Development middleware
      if @app.class.settings.environment == "development"
        @app.class.use Middleware::HttpLogger
        @app.class.use Middleware::TimeLogger
      end
      
      # Session middleware
      @app.class.use Middleware::Session
      
      # Static file serving (should be last)
      if @performance_config.static_file_serving
        if @performance_config.zero_copy_enabled
          @app.class.use Middleware::ZeroCopyStatic.new(nil)
        else
          @app.class.use Middleware::Static
        end
      end
    end
  end
end