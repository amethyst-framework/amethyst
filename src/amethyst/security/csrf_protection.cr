require "digest/sha256"
require "random/secure"
require "../config/security_config"

module Amethyst
  module Security
    # CSRF Protection middleware with clean configuration
    class CSRFProtection < Middleware::Base
      @config : Config::SecurityConfig
      @safe_methods : Set(String)
      @token_generator : Proc(String, String)
      @token_validator : Proc(String, String, Bool)
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?, config : Config::SecurityConfig? = nil)
        super(@app)
        @config = config || Config::SecurityConfig.new
        
        @safe_methods = Set{"GET", "HEAD", "OPTIONS", "TRACE"}
        @token_generator = ->(secret : String) { generate_token(secret) }
        @token_validator = ->(token : String, secret : String) { validate_token(token, secret) }
      end
      
      # Factory method for easy creation
      def self.with_config(config : Config::SecurityConfig)
        new(nil, config)
      end
      
      def call(request) : Http::Response
        # Skip CSRF protection if disabled
        return @app.call(request) unless @config.csrf_enabled
        
        # Skip CSRF protection for safe methods
        if @safe_methods.includes?(request.method.upcase)
          response = @app.call(request)
          return add_csrf_token_to_response(request, response)
        end
        
        # Skip CSRF protection for specified routes
        if @config.csrf_skip_routes.includes?(request.path)
          return @app.call(request)
        end
        
        # Check for valid CSRF token
        unless valid_csrf_token?(request)
          return handle_csrf_failure(request)
        end
        
        response = @app.call(request)
        add_csrf_token_to_response(request, response)
      end
      
      def generate_csrf_token(session : Hash(String, String)? = nil) : String
        token = @token_generator.call(@config.csrf_secret_key)
        
        # Store in session if available
        if session
          session[@config.csrf_session_key] = token
        end
        
        token
      end
      
      def verify_csrf_token(token : String, session : Hash(String, String)? = nil) : Bool
        return false if token.empty?
        
        # Check against session token if available
        if session && (session_token = session[@config.csrf_session_key]?)
          return constant_time_compare(token, session_token)
        end
        
        @token_validator.call(token, @config.csrf_secret_key)
      end
      
# Skip routes are now handled via configuration
      def skip_route(path : String)
        @config.csrf_skip_routes << path
      end
      
      def skip_routes(*paths : String)
        paths.each { |path| @config.csrf_skip_routes << path }
      end
      
      private def valid_csrf_token?(request : Http::Request) : Bool
        token = extract_csrf_token(request)
        return false unless token
        
        # Try to get session for token verification
        session = extract_session_from_request(request)
        verify_csrf_token(token, session)
      end
      
      private def extract_csrf_token(request : Http::Request) : String?
        # Check header first
        token = request.headers[@config.csrf_header_name]?
        return token if token && !token.empty?
        
        # Check form data
        if content_type = request.headers["Content-Type"]?
          if content_type.includes?("application/x-www-form-urlencoded") || 
             content_type.includes?("multipart/form-data")
            return extract_token_from_body(request)
          end
        end
        
        # Check cookies
        request.headers["Cookie"]?.try do |cookie_header|
          cookies = parse_cookies(cookie_header)
          cookies[@config.csrf_cookie_name]?
        end
      end
      
      private def extract_token_from_body(request : Http::Request) : String?
        body = request.body.try(&.to_s) || ""
        return nil if body.empty?
        
        # Parse form data to find token
        params = parse_form_data(body)
        params[@config.csrf_token_name]?
      end
      
      private def parse_form_data(body : String) : Hash(String, String)
        params = Hash(String, String).new
        
        body.split("&").each do |pair|
          if pair.includes?("=")
            key, value = pair.split("=", 2)
            params[URI.decode_www_form(key)] = URI.decode_www_form(value)
          end
        end
        
        params
      end
      
      private def parse_cookies(cookie_header : String) : Hash(String, String)
        cookies = Hash(String, String).new
        
        cookie_header.split(";").each do |cookie|
          if cookie.includes?("=")
            key, value = cookie.strip.split("=", 2)
            cookies[key] = value
          end
        end
        
        cookies
      end
      
      private def extract_session_from_request(request : Http::Request) : Hash(String, String)?
        # This is a simplified session extraction
        # In practice, you'd integrate with your session middleware
        cookies = request.headers["Cookie"]?.try { |c| parse_cookies(c) }
        return nil unless cookies
        
        session_id = cookies["session_id"]?
        return nil unless session_id
        
        # Mock session lookup - replace with actual session store
        {"_csrf_token" => "mock_token"}
      end
      
      private def add_csrf_token_to_response(request : Http::Request, response : Http::Response) : Http::Response
        # Generate new token for next request
        token = generate_csrf_token
        
        # Set token in cookie
        cookie_value = build_cookie_value(token)
        response.headers["Set-Cookie"] = "#{@config.csrf_cookie_name}=#{token}; #{cookie_value}"
        
        # Add token to response headers for JavaScript access
        response.headers["X-CSRF-Token"] = token
        
        response
      end
      
      private def build_cookie_value(token : String) : String
        options = [] of String
        
        if domain = @config.csrf_cookie_domain
          options << "Domain=#{domain}"
        end
        
        options << "Path=#{@config.csrf_cookie_path}"
        
        if @config.csrf_cookie_secure
          options << "Secure"
        end
        
        if @config.csrf_cookie_http_only
          options << "HttpOnly"
        end
        
        if same_site = @config.csrf_cookie_same_site
          options << "SameSite=#{same_site}"
        end
        
        options.join("; ")
      end
      
      private def handle_csrf_failure(request : Http::Request) : Http::Response
        if callback = @config.csrf_failure_callback
          return callback.call(request, Http::Response.new(403, "CSRF token verification failed"))
        end
        
        response = Http::Response.new(403, "CSRF token verification failed")
        response.headers["Content-Type"] = "application/json"
        response.body = {
          error: "CSRF token verification failed",
          message: "The request could not be completed due to invalid CSRF token"
        }.to_json
        
        response
      end
      
      private def generate_token(secret : String) : String
        # Generate a secure random token
        random_bytes = Random::Secure.random_bytes(32)
        timestamp = Time.utc.to_unix.to_s
        
        # Create HMAC with secret, random bytes, and timestamp
        hmac_data = "#{random_bytes.hexstring}:#{timestamp}"
        hmac = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, secret, hmac_data)
        
        # Encode as base64 for safe transport
        Base64.strict_encode("#{hmac_data}:#{hmac.hexstring}")
      end
      
      private def validate_token(token : String, secret : String) : Bool
        return false if token.empty?
        
        begin
          decoded = Base64.decode_string(token)
          parts = decoded.split(":")
          return false unless parts.size == 3
          
          random_hex, timestamp, hmac_hex = parts
          
          # Check if token is not too old (1 hour expiry)
          token_time = timestamp.to_i64
          current_time = Time.utc.to_unix
          return false if current_time - token_time > 3600
          
          # Verify HMAC
          hmac_data = "#{random_hex}:#{timestamp}"
          expected_hmac = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, secret, hmac_data)
          
          constant_time_compare(hmac_hex, expected_hmac.hexstring)
          
        rescue
          false
        end
      end
      
      private def constant_time_compare(a : String, b : String) : Bool
        return false if a.size != b.size
        
        result = 0
        a.size.times do |i|
          result |= a[i].ord ^ b[i].ord
        end
        
        result == 0
      end
    end
    
    # CSRF Helper methods for controllers
    module CSRFHelpers
      def csrf_token(session : Hash(String, String)? = nil) : String
        # Get CSRF protection middleware instance
        csrf_middleware = find_csrf_middleware
        return "" unless csrf_middleware
        
        csrf_middleware.generate_csrf_token(session)
      end
      
      def verify_csrf_token(token : String, session : Hash(String, String)? = nil) : Bool
        csrf_middleware = find_csrf_middleware
        return false unless csrf_middleware
        
        csrf_middleware.verify_csrf_token(token, session)
      end
      
      def csrf_meta_tags : String
        token = csrf_token
        %(<meta name="csrf-param" content="authenticity_token" />\n<meta name="csrf-token" content="#{token}" />)
      end
      
      def csrf_token_tag : String
        token = csrf_token
        %(<input type="hidden" name="authenticity_token" value="#{token}" />)
      end
      
      private def find_csrf_middleware : CSRFProtection?
        # This would need to be implemented to find the CSRF middleware instance
        # from the middleware stack - simplified for now
        nil
      end
    end
    
    # Form helper with automatic CSRF protection
    class SecureForm
      @csrf_token : String
      @action : String
      @method : String
      @multipart : Bool
      
      def initialize(@action : String, @method : String = "POST", 
                     @csrf_token : String = "", @multipart : Bool = false)
      end
      
      def self.form_with(action : String, method : String = "POST", 
                        csrf_token : String = "", multipart : Bool = false, &block)
        form = new(action, method, csrf_token, multipart)
        html = form.open_tag
        html += yield form
        html += form.close_tag
        html
      end
      
      def open_tag : String
        enctype = @multipart ? %( enctype="multipart/form-data") : ""
        %(<form action="#{@action}" method="#{@method}"#{enctype}>\n#{csrf_token_field})
      end
      
      def close_tag : String
        "</form>"
      end
      
      def csrf_token_field : String
        return "" if @csrf_token.empty?
        %(<input type="hidden" name="authenticity_token" value="#{@csrf_token}" />\n)
      end
      
      def text_field(name : String, value : String = "", **attributes) : String
        attrs = build_attributes(attributes)
        %(<input type="text" name="#{name}" value="#{HTML.escape(value)}"#{attrs} />)
      end
      
      def password_field(name : String, **attributes) : String
        attrs = build_attributes(attributes)
        %(<input type="password" name="#{name}"#{attrs} />)
      end
      
      def email_field(name : String, value : String = "", **attributes) : String
        attrs = build_attributes(attributes)
        %(<input type="email" name="#{name}" value="#{HTML.escape(value)}"#{attrs} />)
      end
      
      def submit_button(text : String = "Submit", **attributes) : String
        attrs = build_attributes(attributes)
        %(<button type="submit"#{attrs}>#{HTML.escape(text)}</button>)
      end
      
      private def build_attributes(attributes : Hash) : String
        return "" if attributes.empty?
        
        attrs = attributes.map do |key, value|
          %( #{key}="#{HTML.escape(value.to_s)}")
        end
        
        attrs.join
      end
    end
  end
end