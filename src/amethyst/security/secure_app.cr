require "../realtime/enhanced_app"
require "./csrf_protection"
require "./xss_protection"
require "./sql_injection_protection"
require "./rate_limiting"
require "./jwt_authentication"
require "./secure_headers"

module Amethyst
  module Base
    class SecureApp < RealtimeApp
      @security_config : Security::SecurityConfig
      @jwt_service : Security::JWTService?
      @rate_limit_config : Security::RateLimitConfig
      @csrf_protection : Security::CSRFProtection
      @xss_protection : Security::XSSProtection
      @sql_injection_protection : Security::SQLInjectionProtection
      @secure_headers : Security::SecureHeaders
      @jwt_authentication : Security::JWTAuthentication?
      @security_audit_enabled : Bool
      
      def initialize(app_path, app_type={{@type.name.stringify}},
                     enable_http2 : Bool = true,
                     enable_caching : Bool = true,
                     cache_size : Int64 = 100_000_000,
                     enable_realtime_auth : Bool = false,
                     enable_realtime_rate_limiting : Bool = true,
                     connection_cleanup_interval : Time::Span = 5.minutes,
                     security_config : Security::SecurityConfig? = nil)
        
        super(app_path, app_type, enable_http2, enable_caching, cache_size, 
              enable_realtime_auth, enable_realtime_rate_limiting, connection_cleanup_interval)
        
        @security_config = security_config || Security::SecurityConfig.production
        @security_audit_enabled = @security_config.enable_security_audit
        
        setup_security_middleware
      end
      
      def configure_jwt(secret_key : String, **options)
        jwt_config = Security::JWTConfig.new(secret_key, **options)
        @jwt_service = Security::JWTService.new(jwt_config)
        
        # Update JWT authentication middleware
        if jwt_service = @jwt_service
          @jwt_authentication = Security::JWTAuthentication.new(nil, jwt_service)
          rebuild_middleware_stack
        end
      end
      
      def configure_rate_limiting(&block : Security::RateLimitConfig -> Nil)
        block.call(@rate_limit_config)
        rebuild_middleware_stack
      end
      
      def configure_csrf(secret_key : String? = nil, **options)
        @csrf_protection = Security::CSRFProtection.new(nil, secret_key || Random::Secure.hex(32), **options)
        rebuild_middleware_stack
      end
      
      def configure_xss(**options)
        @xss_protection = Security::XSSProtection.new(nil, **options)
        rebuild_middleware_stack
      end
      
      def configure_secure_headers(**options)
        @secure_headers = Security::SecureHeaders.new(nil, **options)
        rebuild_middleware_stack
      end
      
      def security_audit(request_url : String, response_headers : ::HTTP::Headers, is_https : Bool) : Hash(String, Hash(String, String | Bool))
        return {} of String => Hash(String, String | Bool) unless @security_audit_enabled
        
        audit = Security::SecurityAudit.new(response_headers, request_url, is_https)
        audit.audit
      end
      
      def security_score(request_url : String, response_headers : ::HTTP::Headers, is_https : Bool) : Int32
        return 0 unless @security_audit_enabled
        
        audit = Security::SecurityAudit.new(response_headers, request_url, is_https)
        audit.security_score
      end
      
      # Security helper methods for controllers
      def generate_jwt_token(user_id : String, **options) : String?
        @jwt_service.try(&.generate_token(user_id, **options))
      end
      
      def verify_jwt_token(token : String) : Security::JWTToken?
        @jwt_service.try(&.verify_token(token))
      end
      
      def blacklist_jwt_token(token : String) : Bool
        @jwt_service.try(&.blacklist_token(token)) || false
      end
      
      def generate_csrf_token : String
        @csrf_protection.generate_csrf_token
      end
      
      def verify_csrf_token(token : String) : Bool
        @csrf_protection.verify_csrf_token(token)
      end
      
      # Class-level security configuration methods
      def self.configure_security(&block : Security::SecurityConfig -> Nil)
        config = Security::SecurityConfig.new
        block.call(config)
        instance.update_security_config(config)
      end
      
      def update_security_config(config : Security::SecurityConfig)
        @security_config = config
        setup_security_middleware
      end
      
      def self.enable_jwt_authentication(secret_key : String, **options)
        instance.configure_jwt(secret_key, **options)
      end
      
      def self.configure_rate_limits(&block : Security::RateLimitConfig -> Nil)
        instance.configure_rate_limiting(&block)
      end
      
      def self.enable_strict_security
        instance.update_security_config(Security::SecurityConfig.strict)
      end
      
      def self.enable_development_security
        instance.update_security_config(Security::SecurityConfig.development)
      end
      
      # Security monitoring endpoints
      def self.security_audit_endpoint(path : String = "/security/audit")
        get path, "SecurityAuditController", "audit"
      end
      
      def self.security_headers_check(path : String = "/security/headers")
        get path, "SecurityHeadersController", "check"
      end
      
      private def setup_security_middleware
        # Clear existing middleware and rebuild with security
        self.class.middleware.clear
        
        # Security middleware stack (order matters!)
        # 1. Secure headers (first to set security headers)
        @secure_headers = create_secure_headers_middleware
        self.class.use @secure_headers
        
        # 2. Rate limiting (before any processing)
        setup_rate_limiting_middleware
        
        # 3. CSRF protection (before form processing)
        @csrf_protection = create_csrf_middleware
        self.class.use @csrf_protection
        
        # 4. XSS protection (before content processing)
        @xss_protection = create_xss_middleware
        self.class.use @xss_protection
        
        # 5. SQL injection protection (before database queries)
        @sql_injection_protection = create_sql_injection_middleware
        self.class.use @sql_injection_protection
        
        # 6. JWT authentication (after input validation)
        setup_jwt_middleware
        
        # 7. Exception handling (keep at top of application middleware)
        self.class.use Middleware::ShowExceptions
        
        # 8. Realtime authentication and rate limiting
        if @enable_realtime_auth || @enable_realtime_rate_limiting
          setup_realtime_security_middleware
        end
        
        # 9. Caching middleware (after authentication)
        if @enable_caching
          self.class.use Middleware::ETagCache
          self.class.use Middleware::ConditionalGet
          self.class.use @response_cache
        end
        
        # 10. Development middleware
        if self.class.settings.environment == "development"
          self.class.use Middleware::HttpLogger
          self.class.use Middleware::TimeLogger
        end
        
        # 11. Session middleware (after security checks)
        self.class.use Middleware::Session
        
        # 12. Static file serving (last)
        self.class.use Middleware::Static
        
        rebuild_middleware_stack
      end
      
      private def create_secure_headers_middleware : Security::SecureHeaders
        case @security_config.security_level
        when "strict"
          Security::SecureHeaders.strict_security(self.class.settings.environment)
        when "moderate"
          Security::SecureHeaders.moderate_security(self.class.settings.environment)
        when "development"
          Security::SecureHeaders.development_security
        else
          Security::SecureHeaders.new
        end
      end
      
      private def create_csrf_middleware : Security::CSRFProtection
        Security::CSRFProtection.new(
          nil,
          secret_key: @security_config.csrf_secret || Random::Secure.hex(32),
          skip_routes: @security_config.csrf_skip_routes
        )
      end
      
      private def create_xss_middleware : Security::XSSProtection
        Security::XSSProtection.new(
          nil,
          auto_escape_html: @security_config.xss_auto_escape,
          sanitize_json_responses: @security_config.xss_sanitize_json,
          content_security_policy: @security_config.content_security_policy
        )
      end
      
      private def create_sql_injection_middleware : Security::SQLInjectionProtection
        Security::SQLInjectionProtection.new(
          nil,
          check_query_params: @security_config.sql_check_query_params,
          check_form_data: @security_config.sql_check_form_data,
          check_json_data: @security_config.sql_check_json_data
        )
      end
      
      private def setup_rate_limiting_middleware
        @rate_limit_config.build_middlewares.each do |middleware|
          self.class.use middleware
        end
      end
      
      private def setup_jwt_middleware
        return unless @jwt_service
        
        @jwt_authentication = Security::JWTAuthentication.new(nil, @jwt_service.not_nil!)
        
        # Configure JWT middleware based on security config
        @security_config.jwt_skip_routes.each do |route|
          @jwt_authentication.not_nil!.skip_route(route)
        end
        
        @security_config.jwt_optional_routes.each do |route|
          @jwt_authentication.not_nil!.optional_auth_route(route)
        end
        
        self.class.use @jwt_authentication.not_nil!
      end
      
      private def setup_realtime_security_middleware
        # Additional security for realtime connections
        if @enable_realtime_auth && @jwt_service
          realtime_auth = Realtime::RealtimeAuth.new(nil, ->(request : Http::Request) {
            auth_header = request.headers["Authorization"]?
            return false unless auth_header
            
            token = @jwt_service.not_nil!.extract_token_from_header(auth_header)
            return false unless token
            
            jwt_token = @jwt_service.not_nil!.verify_token(token)
            !jwt_token.nil?
          })
          
          self.class.use realtime_auth
        end
        
        if @enable_realtime_rate_limiting
          self.class.use Realtime::RealtimeRateLimit.new
        end
      end
      
      private def rebuild_middleware_stack
        @app = Middleware::MiddlewareStack.instance.build_middleware
        @http_handler = Base::Handler.new(@app)
      end
      
      private def self.instance
        @@instance ||= new(__FILE__)
      end
    end
  end
  
  # Security configuration class
  module Security
    class SecurityConfig
      property security_level : String
      property enable_security_audit : Bool
      property csrf_secret : String?
      property csrf_skip_routes : Set(String)
      property xss_auto_escape : Bool
      property xss_sanitize_json : Bool
      property sql_check_query_params : Bool
      property sql_check_form_data : Bool
      property sql_check_json_data : Bool
      property content_security_policy : String?
      property jwt_skip_routes : Set(String)
      property jwt_optional_routes : Set(String)
      
      def initialize(@security_level : String = "moderate",
                     @enable_security_audit : Bool = true,
                     @csrf_secret : String? = nil,
                     @csrf_skip_routes : Set(String) = Set(String).new,
                     @xss_auto_escape : Bool = true,
                     @xss_sanitize_json : Bool = true,
                     @sql_check_query_params : Bool = true,
                     @sql_check_form_data : Bool = true,
                     @sql_check_json_data : Bool = true,
                     @content_security_policy : String? = nil,
                     @jwt_skip_routes : Set(String) = Set{"/", "/login", "/register", "/health"},
                     @jwt_optional_routes : Set(String) = Set{"/public"})
      end
      
      def self.strict : SecurityConfig
        new(
          security_level: "strict",
          enable_security_audit: true,
          xss_auto_escape: true,
          xss_sanitize_json: true,
          sql_check_query_params: true,
          sql_check_form_data: true,
          sql_check_json_data: true,
          content_security_policy: "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none'",
          jwt_skip_routes: Set{"/health"},
          jwt_optional_routes: Set(String).new
        )
      end
      
      def self.moderate : SecurityConfig
        new(
          security_level: "moderate",
          enable_security_audit: true,
          xss_auto_escape: true,
          xss_sanitize_json: true,
          sql_check_query_params: true,
          sql_check_form_data: true,
          sql_check_json_data: false,
          content_security_policy: "default-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'",
          jwt_skip_routes: Set{"/", "/login", "/register", "/health", "/public"},
          jwt_optional_routes: Set{"/api/public"}
        )
      end
      
      def self.development : SecurityConfig
        new(
          security_level: "development",
          enable_security_audit: false,
          xss_auto_escape: false,
          xss_sanitize_json: false,
          sql_check_query_params: true,
          sql_check_form_data: false,
          sql_check_json_data: false,
          content_security_policy: nil,
          jwt_skip_routes: Set{"/", "/login", "/register", "/health", "/public", "/dev"},
          jwt_optional_routes: Set{"/api"}
        )
      end
      
      def self.production : SecurityConfig
        strict
      end
      
      def skip_csrf_for_route(route : String)
        @csrf_skip_routes << route
      end
      
      def skip_jwt_for_route(route : String)
        @jwt_skip_routes << route
      end
      
      def optional_jwt_for_route(route : String)
        @jwt_optional_routes << route
      end
    end
  end
  
  # Security audit controller
  class SecurityAuditController < ::Amethyst::Controller
    include Security::SecureHeadersHelpers
    
    def audit
      require_admin_access
      
      request_url = request.path
      is_https = request.headers["X-Forwarded-Proto"]? == "https"
      
      if app_instance = Base::SecureApp.send(:instance)
        audit_results = app_instance.security_audit(request_url, response.headers, is_https)
        security_score = app_instance.security_score(request_url, response.headers, is_https)
        
        result = {
          security_score: security_score,
          audit_results: audit_results,
          timestamp: Time.utc.to_rfc3339,
          request_url: request_url,
          https_enabled: is_https
        }
        
        response.content_type = "application/json"
        prevent_caching
        result.to_json
      else
        response.status_code = 500
        {error: "Security audit not available"}.to_json
      end
    end
    
    private def require_admin_access
      # Implement your admin access check here
      # For example, check JWT token for admin role
      unless has_role?("admin")
        response.status_code = 403
        response.body = {error: "Admin access required"}.to_json
        return
      end
    end
  end
  
  # Security headers check controller
  class SecurityHeadersController < ::Amethyst::Controller
    include Security::SecureHeadersHelpers
    
    def check
      headers_info = {
        security_headers: {
          "Strict-Transport-Security" => response.headers["Strict-Transport-Security"]?,
          "Content-Security-Policy" => response.headers["Content-Security-Policy"]?,
          "X-Frame-Options" => response.headers["X-Frame-Options"]?,
          "X-Content-Type-Options" => response.headers["X-Content-Type-Options"]?,
          "X-XSS-Protection" => response.headers["X-XSS-Protection"]?,
          "Referrer-Policy" => response.headers["Referrer-Policy"]?,
          "Permissions-Policy" => response.headers["Permissions-Policy"]?
        },
        cross_origin_headers: {
          "Cross-Origin-Embedder-Policy" => response.headers["Cross-Origin-Embedder-Policy"]?,
          "Cross-Origin-Opener-Policy" => response.headers["Cross-Origin-Opener-Policy"]?,
          "Cross-Origin-Resource-Policy" => response.headers["Cross-Origin-Resource-Policy"]?
        },
        timestamp: Time.utc.to_rfc3339
      }
      
      response.content_type = "application/json"
      prevent_caching
      headers_info.to_json
    end
  end
end