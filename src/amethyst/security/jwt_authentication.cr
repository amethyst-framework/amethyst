require "jwt"
require "json"
require "openssl/hmac"

module Amethyst
  module Security
    # JWT Configuration
    struct JWTConfig
      property secret_key : String
      property algorithm : JWT::Algorithm
      property expiration_time : Time::Span
      property issuer : String?
      property audience : String?
      property refresh_secret : String?
      property refresh_expiration : Time::Span
      property blacklist_store : TokenBlacklist?
      
      def initialize(@secret_key : String,
                     @algorithm : JWT::Algorithm = JWT::Algorithm::HS256,
                     @expiration_time : Time::Span = 1.hour,
                     @issuer : String? = nil,
                     @audience : String? = nil,
                     @refresh_secret : String? = nil,
                     @refresh_expiration : Time::Span = 7.days,
                     @blacklist_store : TokenBlacklist? = nil)
        @refresh_secret = @refresh_secret || @secret_key
      end
      
      def self.development(secret : String = Random::Secure.hex(32)) : JWTConfig
        new(
          secret_key: secret,
          expiration_time: 24.hours,
          issuer: "amethyst_dev"
        )
      end
      
      def self.production(secret : String, issuer : String, audience : String? = nil) : JWTConfig
        new(
          secret_key: secret,
          algorithm: JWT::Algorithm::HS512,
          expiration_time: 15.minutes,
          issuer: issuer,
          audience: audience,
          refresh_expiration: 30.days
        )
      end
    end
    
    # JWT Token representation
    struct JWTToken
      include JSON::Serializable
      
      property sub : String           # Subject (user ID)
      property exp : Int64            # Expiration time
      property iat : Int64            # Issued at
      property iss : String?          # Issuer
      property aud : String?          # Audience
      property jti : String?          # JWT ID (for blacklisting)
      property scope : String?        # Token scope
      property role : String?         # User role
      property permissions : Array(String)? # User permissions
      
      def initialize(@sub : String, expiration : Time::Span, 
                     @iss : String? = nil, @aud : String? = nil,
                     @scope : String? = nil, @role : String? = nil,
                     @permissions : Array(String)? = nil)
        @iat = Time.utc.to_unix
        @exp = @iat + expiration.total_seconds.to_i64
        @jti = UUID.random.to_s
      end
      
      def expired? : Bool
        Time.utc.to_unix > @exp
      end
      
      def expires_in : Time::Span
        (@exp - Time.utc.to_unix).seconds
      end
      
      def has_permission?(permission : String) : Bool
        permissions = @permissions
        return false unless permissions
        permissions.includes?(permission)
      end
      
      def has_role?(role : String) : Bool
        @role == role
      end
      
      def has_scope?(scope : String) : Bool
        return false unless token_scope = @scope
        token_scope.split(" ").includes?(scope)
      end
    end
    
    # Token blacklist interface
    abstract class TokenBlacklist
      abstract def blacklist(jti : String, expires_at : Time)
      abstract def blacklisted?(jti : String) : Bool
      abstract def cleanup_expired
    end
    
    # Memory-based token blacklist
    class MemoryTokenBlacklist < TokenBlacklist
      @blacklisted_tokens : Hash(String, Time)
      @mutex : Mutex
      
      def initialize
        @blacklisted_tokens = Hash(String, Time).new
        @mutex = Mutex.new
        
        # Start cleanup task
        spawn do
          loop do
            sleep 1.hour
            cleanup_expired
          end
        end
      end
      
      def blacklist(jti : String, expires_at : Time)
        @mutex.synchronize do
          @blacklisted_tokens[jti] = expires_at
        end
      end
      
      def blacklisted?(jti : String) : Bool
        @mutex.synchronize do
          expires_at = @blacklisted_tokens[jti]?
          return false unless expires_at
          
          if Time.utc > expires_at
            @blacklisted_tokens.delete(jti)
            return false
          end
          
          true
        end
      end
      
      def cleanup_expired
        @mutex.synchronize do
          current_time = Time.utc
          expired_tokens = [] of String
          
          @blacklisted_tokens.each do |jti, expires_at|
            if current_time > expires_at
              expired_tokens << jti
            end
          end
          
          expired_tokens.each { |jti| @blacklisted_tokens.delete(jti) }
          expired_tokens.size
        end
      end
      
      def size : Int32
        @mutex.synchronize { @blacklisted_tokens.size }
      end
    end
    
    # JWT Service for token operations
    class JWTService
      @config : JWTConfig
      
      def initialize(@config : JWTConfig)
      end
      
      def generate_token(user_id : String, role : String? = nil, 
                        permissions : Array(String)? = nil,
                        scope : String? = nil) : String
        token = JWTToken.new(
          sub: user_id,
          expiration: @config.expiration_time,
          iss: @config.issuer,
          aud: @config.audience,
          role: role,
          permissions: permissions,
          scope: scope
        )
        
        payload = token.to_json
        JWT.encode(payload, @config.secret_key, @config.algorithm)
      end
      
      def generate_refresh_token(user_id : String) : String
        token = JWTToken.new(
          sub: user_id,
          expiration: @config.refresh_expiration,
          iss: @config.issuer,
          aud: @config.audience,
          scope: "refresh"
        )
        
        payload = token.to_json
        refresh_secret = @config.refresh_secret || @config.secret_key
        JWT.encode(payload, refresh_secret, @config.algorithm)
      end
      
      def verify_token(token : String) : JWTToken?
        begin
          payload, header = JWT.decode(token, @config.secret_key, @config.algorithm)
          jwt_token = JWTToken.from_json(payload)
          
          # Check if token is blacklisted
          if blacklist = @config.blacklist_store
            if jti = jwt_token.jti
              return nil if blacklist.blacklisted?(jti)
            end
          end
          
          # Validate issuer
          if expected_issuer = @config.issuer
            return nil unless jwt_token.iss == expected_issuer
          end
          
          # Validate audience
          if expected_audience = @config.audience
            return nil unless jwt_token.aud == expected_audience
          end
          
          # Check expiration
          return nil if jwt_token.expired?
          
          jwt_token
        rescue ex : JWT::DecodeError | JSON::ParseException
          Base::App.logger.log_string "JWT verification failed: #{ex.message}"
          nil
        end
      end
      
      def verify_refresh_token(token : String) : JWTToken?
        begin
          refresh_secret = @config.refresh_secret || @config.secret_key
          payload, header = JWT.decode(token, refresh_secret, @config.algorithm)
          jwt_token = JWTToken.from_json(payload)
          
          # Check scope is refresh
          return nil unless jwt_token.has_scope?("refresh")
          
          # Check if token is blacklisted
          if blacklist = @config.blacklist_store
            if jti = jwt_token.jti
              return nil if blacklist.blacklisted?(jti)
            end
          end
          
          # Check expiration
          return nil if jwt_token.expired?
          
          jwt_token
        rescue ex : JWT::DecodeError | JSON::ParseException
          Base::App.logger.log_string "Refresh token verification failed: #{ex.message}"
          nil
        end
      end
      
      def refresh_access_token(refresh_token : String, role : String? = nil,
                              permissions : Array(String)? = nil) : String?
        jwt_refresh = verify_refresh_token(refresh_token)
        return nil unless jwt_refresh
        
        generate_token(jwt_refresh.sub, role, permissions)
      end
      
      def blacklist_token(token : String) : Bool
        jwt_token = verify_token(token)
        return false unless jwt_token
        return false unless jti = jwt_token.jti
        
        if blacklist = @config.blacklist_store
          expires_at = Time.unix(jwt_token.exp)
          blacklist.blacklist(jti, expires_at)
          true
        else
          false
        end
      end
      
      def extract_token_from_header(auth_header : String) : String?
        if auth_header.starts_with?("Bearer ")
          auth_header[7..-1].strip
        else
          nil
        end
      end
      
      def create_token_response(access_token : String, refresh_token : String? = nil) : Hash(String, String | Int64)
        jwt_token = verify_token(access_token)
        expires_in = jwt_token.try(&.expires_in.total_seconds.to_i64) || 0
        
        response = {
          "access_token" => access_token,
          "token_type" => "Bearer",
          "expires_in" => expires_in
        }
        
        if refresh_token
          response["refresh_token"] = refresh_token
        end
        
        response
      end
    end
    
    # JWT Authentication middleware
    class JWTAuthentication < Middleware::Base
      @jwt_service : JWTService
      @skip_routes : Set(String)
      @optional_routes : Set(String)
      @role_requirements : Hash(String, String)
      @permission_requirements : Hash(String, Array(String))
      @token_extractors : Array(Proc(Http::Request, String?))
      @failure_callback : Proc(Http::Request, String, Http::Response)?
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        config = JWTConfig.new("default-secret")
        @jwt_service = JWTService.new(config)
        @skip_routes = Set(String).new
        @optional_routes = Set(String).new
        @failure_callback = nil
        
        @role_requirements = Hash(String, String).new
        @permission_requirements = Hash(String, Array(String)).new
        
        @token_extractors = [
          # Authorization header
          ->(request : Http::Request) {
            auth_header = request.headers["Authorization"]?
            auth_header ? @jwt_service.extract_token_from_header(auth_header) : nil
          },
          # Cookie
          ->(request : Http::Request) {
            cookies = parse_cookies(request.headers["Cookie"]?)
            cookies["access_token"]?
          },
          # Query parameter
          ->(request : Http::Request) {
            query = request.query_string
            return nil unless query
            
            params = parse_query_params(query)
            params["access_token"]?
          }
        ]
      end
      
      def call(request) : Http::Response
        # Skip authentication for specified routes
        if @skip_routes.includes?(request.path)
          return @app.call(request)
        end
        
        # Extract token
        token = extract_token(request)
        
        # Handle optional authentication routes
        if @optional_routes.includes?(request.path)
          if token
            if jwt_token = @jwt_service.verify_token(token)
              set_current_user(request, jwt_token)
            end
          end
          return @app.call(request)
        end
        
        # Require token for other routes
        unless token
          return handle_authentication_failure(request, "Missing authentication token")
        end
        
        # Verify token
        jwt_token = @jwt_service.verify_token(token)
        unless jwt_token
          return handle_authentication_failure(request, "Invalid or expired token")
        end
        
        # Check role requirements
        if required_role = @role_requirements[request.path]?
          unless jwt_token.has_role?(required_role)
            return handle_authorization_failure(request, "Insufficient role permissions")
          end
        end
        
        # Check permission requirements
        if required_permissions = @permission_requirements[request.path]?
          unless required_permissions.all? { |perm| jwt_token.has_permission?(perm) }
            return handle_authorization_failure(request, "Insufficient permissions")
          end
        end
        
        # Set current user context
        set_current_user(request, jwt_token)
        
        @app.call(request)
      end
      
      def skip_route(path : String)
        @skip_routes << path
      end
      
      def skip_routes(*paths : String)
        paths.each { |path| @skip_routes << path }
      end
      
      def optional_auth_route(path : String)
        @optional_routes << path
      end
      
      def require_role(path : String, role : String)
        @role_requirements[path] = role
      end
      
      def require_permissions(path : String, *permissions : String)
        @permission_requirements[path] = permissions.to_a
      end
      
      def add_token_extractor(&extractor : Http::Request -> String?)
        @token_extractors << extractor
      end
      
      private def extract_token(request : Http::Request) : String?
        @token_extractors.each do |extractor|
          if token = extractor.call(request)
            return token unless token.empty?
          end
        end
        
        nil
      end
      
      private def set_current_user(request : Http::Request, jwt_token : JWTToken)
        # Store JWT token in request context for controllers to access
        # This would need to be implemented with a request context system
        # request.context["current_user"] = jwt_token
      end
      
      private def handle_authentication_failure(request : Http::Request, message : String) : Http::Response
        if callback = @failure_callback
          return callback.call(request, message)
        end
        
        response = Http::Response.new(401, "")
        response.headers["Content-Type"] = "application/json"
        response.headers["WWW-Authenticate"] = "Bearer"
        
        error_body = {
          error: "authentication_required",
          message: message
        }
        
        response.body = error_body.to_json
        response
      end
      
      private def handle_authorization_failure(request : Http::Request, message : String) : Http::Response
        response = Http::Response.new(403, "")
        response.headers["Content-Type"] = "application/json"
        
        error_body = {
          error: "insufficient_permissions",
          message: message
        }
        
        response.body = error_body.to_json
        response
      end
      
      private def parse_cookies(cookie_header : String?) : Hash(String, String)
        cookies = Hash(String, String).new
        return cookies unless cookie_header
        
        cookie_header.split(";").each do |cookie|
          if cookie.includes?("=")
            key, value = cookie.strip.split("=", 2)
            cookies[key] = value
          end
        end
        
        cookies
      end
      
      private def parse_query_params(query : String) : Hash(String, String)
        params = Hash(String, String).new
        
        query.split("&").each do |param|
          if param.includes?("=")
            key, value = param.split("=", 2)
            params[URI.decode_www_form(key)] = URI.decode_www_form(value)
          end
        end
        
        params
      end
    end
    
    # JWT helper methods for controllers
    module JWTHelpers
      def current_user : JWTToken?
        # Get current user from request context
        # This would be set by the JWT middleware
        # request.context["current_user"]?.try(&.as(JWTToken))
        nil # Placeholder
      end
      
      def current_user_id : String?
        current_user.try(&.sub)
      end
      
      def current_user_role : String?
        current_user.try(&.role)
      end
      
      def current_user_permissions : Array(String)?
        current_user.try(&.permissions)
      end
      
      def authenticated? : Bool
        !current_user.nil?
      end
      
      def has_role?(role : String) : Bool
        current_user.try(&.has_role?(role)) || false
      end
      
      def has_permission?(permission : String) : Bool
        current_user.try(&.has_permission?(permission)) || false
      end
      
      def has_any_permission?(*permissions : String) : Bool
        user = current_user
        return false unless user
        
        permissions.any? { |perm| user.has_permission?(perm) }
      end
      
      def has_all_permissions?(*permissions : String) : Bool
        user = current_user
        return false unless user
        
        permissions.all? { |perm| user.has_permission?(perm) }
      end
      
      def require_authentication!
        unless authenticated?
          response.status_code = 401
          response.headers["Content-Type"] = "application/json"
          response.body = {error: "Authentication required"}.to_json
          return
        end
      end
      
      def require_role!(role : String)
        require_authentication!
        
        unless has_role?(role)
          response.status_code = 403
          response.headers["Content-Type"] = "application/json"
          response.body = {error: "Insufficient role permissions"}.to_json
          return
        end
      end
      
      def require_permission!(permission : String)
        require_authentication!
        
        unless has_permission?(permission)
          response.status_code = 403
          response.headers["Content-Type"] = "application/json"
          response.body = {error: "Insufficient permissions"}.to_json
          return
        end
      end
    end
    
    # Authentication controller for login/logout endpoints
    class AuthController
      include JWTHelpers
      
      @jwt_service : JWTService
      @user_authenticator : Proc(String, String, Hash(String, String)?)
      
      def initialize(@jwt_service : JWTService,
                     @user_authenticator : Proc(String, String, Hash(String, String)?))
      end
      
      def login(request : Http::Request) : Http::Response
        begin
          body = JSON.parse(request.body.to_s)
          username = body["username"]?.try(&.as_s)
          password = body["password"]?.try(&.as_s)
          
          unless username && password
            return error_response(400, "Username and password required")
          end
          
          # Authenticate user
          user_info = @user_authenticator.call(username, password)
          unless user_info
            return error_response(401, "Invalid credentials")
          end
          
          # Extract user details
          user_id = user_info["id"]
          role = user_info["role"]?
          permissions_str = user_info["permissions"]?
          permissions = permissions_str ? permissions_str.split(",") : nil
          
          # Generate tokens
          access_token = @jwt_service.generate_token(user_id, role, permissions)
          refresh_token = @jwt_service.generate_refresh_token(user_id)
          
          # Create response
          token_response = @jwt_service.create_token_response(access_token, refresh_token)
          
          response = Http::Response.new(200, "")
          response.headers["Content-Type"] = "application/json"
          response.body = token_response.to_json
          response
          
        rescue JSON::ParseException
          error_response(400, "Invalid JSON")
        rescue ex
          Base::App.logger.log_string "Login error: #{ex.message}"
          error_response(500, "Internal server error")
        end
      end
      
      def refresh(request : Http::Request) : Http::Response
        begin
          body = JSON.parse(request.body.to_s)
          refresh_token = body["refresh_token"]?.try(&.as_s)
          
          unless refresh_token
            return error_response(400, "Refresh token required")
          end
          
          # Get user info for new access token
          jwt_refresh = @jwt_service.verify_refresh_token(refresh_token)
          unless jwt_refresh
            return error_response(401, "Invalid refresh token")
          end
          
          # Generate new access token
          user_info = get_user_info(jwt_refresh.sub)
          role = user_info.try(&.["role"]?)
          permissions_str = user_info.try(&.["permissions"]?)
          permissions = permissions_str ? permissions_str.split(",") : nil
          
          access_token = @jwt_service.generate_token(jwt_refresh.sub, role, permissions)
          
          # Create response
          token_response = @jwt_service.create_token_response(access_token)
          
          response = Http::Response.new(200, "")
          response.headers["Content-Type"] = "application/json"
          response.body = token_response.to_json
          response
          
        rescue JSON::ParseException
          error_response(400, "Invalid JSON")
        rescue ex
          Base::App.logger.log_string "Token refresh error: #{ex.message}"
          error_response(500, "Internal server error")
        end
      end
      
      def logout(request : Http::Request) : Http::Response
        # Extract token from request
        auth_header = request.headers["Authorization"]?
        unless auth_header
          return error_response(400, "Authorization header required")
        end
        
        token = @jwt_service.extract_token_from_header(auth_header)
        unless token
          return error_response(400, "Invalid authorization header")
        end
        
        # Blacklist the token
        success = @jwt_service.blacklist_token(token)
        
        response = Http::Response.new(200, "")
        response.headers["Content-Type"] = "application/json"
        response.body = {message: "Logged out successfully"}.to_json
        response
      end
      
      def profile(request : Http::Request) : Http::Response
        user = current_user
        unless user
          return error_response(401, "Authentication required")
        end
        
        user_info = get_user_info(user.sub)
        
        response = Http::Response.new(200, "")
        response.headers["Content-Type"] = "application/json"
        response.body = user_info.to_json
        response
      end
      
      private def error_response(status : Int32, message : String) : Http::Response
        response = Http::Response.new(status, "")
        response.headers["Content-Type"] = "application/json"
        response.body = {error: message}.to_json
        response
      end
      
      private def get_user_info(user_id : String) : Hash(String, String)?
        # This would query your user database
        # For now, return mock data
        {
          "id" => user_id,
          "username" => "user_#{user_id}",
          "role" => "user",
          "permissions" => "read,write"
        }
      end
    end
  end
end