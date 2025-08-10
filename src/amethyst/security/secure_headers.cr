module Amethyst
  module Security
    # Secure Headers middleware for automatic security header injection
    class SecureHeaders < Middleware::Base
      @force_https : Bool
      @hsts_max_age : Int32?
      @hsts_include_subdomains : Bool
      @hsts_preload : Bool
      @content_type_nosniff : Bool
      @frame_options : String?
      @xss_protection : String?
      @referrer_policy : String?
      @permissions_policy : String?
      @content_security_policy : String?
      @csp_report_only : Bool
      @expect_certificate_transparency : Bool
      @cross_origin_embedder_policy : String?
      @cross_origin_opener_policy : String?
      @cross_origin_resource_policy : String?
      @custom_headers : Hash(String, String)
      @remove_headers : Array(String)
      @skip_routes : Set(String)
      @environment : String
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @force_https = true
        @hsts_max_age = 31536000 # 1 year
        @hsts_include_subdomains = true
        @hsts_preload = false
        @content_type_nosniff = true
        @frame_options = "DENY"
        @xss_protection = "1; mode=block"
        @referrer_policy = "strict-origin-when-cross-origin"
        @permissions_policy = nil
        @content_security_policy = nil
        @csp_report_only = false
        @expect_certificate_transparency = false
        @cross_origin_embedder_policy = "require-corp"
        @cross_origin_opener_policy = "same-origin"
        @cross_origin_resource_policy = "same-origin"
        @custom_headers = Hash(String, String).new
        @remove_headers = ["Server", "X-Powered-By"]
        @skip_routes = Set(String).new
        @environment = "production"
      end
      
      def call(request : Http::Request) : Http::Response
        # Skip secure headers for specified routes
        if @skip_routes.includes?(request.path)
          return @app.call(request)
        end
        
        # Process request
        response = @app.call(request)
        
        # Apply secure headers
        apply_security_headers(request, response)
      end
      
      def skip_route(path : String)
        @skip_routes << path
      end
      
      def skip_routes(*paths : String)
        paths.each { |path| @skip_routes << path }
      end
      
      def add_custom_header(name : String, value : String)
        @custom_headers[name] = value
      end
      
      def remove_header(name : String)
        @remove_headers << name unless @remove_headers.includes?(name)
      end
      
      private def apply_security_headers(request : Http::Request, response : Http::Response) : Http::Response
        # Remove unwanted headers that reveal server information
        @remove_headers.each do |header|
          response.headers.delete(header)
        end
        
        # Force HTTPS redirect
        if @force_https && !is_https_request?(request)
          return redirect_to_https(request)
        end
        
        # HTTP Strict Transport Security (HSTS)
        if hsts_max_age = @hsts_max_age
          hsts_value = "max-age=#{hsts_max_age}"
          hsts_value += "; includeSubDomains" if @hsts_include_subdomains
          hsts_value += "; preload" if @hsts_preload
          response.headers["Strict-Transport-Security"] = hsts_value
        end
        
        # Content Type Options
        if @content_type_nosniff
          response.headers["X-Content-Type-Options"] = "nosniff"
        end
        
        # Frame Options
        if frame_options = @frame_options
          response.headers["X-Frame-Options"] = frame_options
        end
        
        # XSS Protection
        if xss_protection = @xss_protection
          response.headers["X-XSS-Protection"] = xss_protection
        end
        
        # Referrer Policy
        if referrer_policy = @referrer_policy
          response.headers["Referrer-Policy"] = referrer_policy
        end
        
        # Permissions Policy (formerly Feature Policy)
        if permissions_policy = @permissions_policy
          response.headers["Permissions-Policy"] = permissions_policy
        end
        
        # Content Security Policy
        if csp = @content_security_policy
          header_name = @csp_report_only ? "Content-Security-Policy-Report-Only" : "Content-Security-Policy"
          response.headers[header_name] = csp
        end
        
        # Certificate Transparency
        if @expect_certificate_transparency
          response.headers["Expect-CT"] = "max-age=86400, enforce"
        end
        
        # Cross-Origin Policies
        if coep = @cross_origin_embedder_policy
          response.headers["Cross-Origin-Embedder-Policy"] = coep
        end
        
        if coop = @cross_origin_opener_policy
          response.headers["Cross-Origin-Opener-Policy"] = coop
        end
        
        if corp = @cross_origin_resource_policy
          response.headers["Cross-Origin-Resource-Policy"] = corp
        end
        
        # Cache Control for sensitive routes
        if is_sensitive_route?(request)
          response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
          response.headers["Pragma"] = "no-cache"
          response.headers["Expires"] = "0"
        end
        
        # Custom headers
        @custom_headers.each do |name, value|
          response.headers[name] = value
        end
        
        # Development vs Production headers
        apply_environment_specific_headers(response)
        
        response
      end
      
      private def is_https_request?(request : Http::Request) : Bool
        # Check if the request is HTTPS
        scheme = request.headers["X-Forwarded-Proto"]? || 
                request.headers["X-Forwarded-Scheme"]? ||
                request.headers["X-Scheme"]?
        
        return true if scheme && scheme.downcase == "https"
        
        # Check if connection is secure (this would need to be implemented
        # based on the actual server setup)
        false
      end
      
      private def redirect_to_https(request : Http::Request) : Http::Response
        # Build HTTPS URL
        host = request.headers["Host"]? || "localhost"
        path = request.path
        query = request.query
        
        https_url = "https://#{host}#{path}"
        https_url += "?#{query}" if query && !query.empty?
        
        response = Http::Response.new(301, "")
        response.headers["Location"] = https_url
        response.headers["Content-Type"] = "text/plain"
        response.body = "Redirecting to HTTPS"
        
        response
      end
      
      private def is_sensitive_route?(request : Http::Request) : Bool
        sensitive_patterns = [
          /\/admin/,
          /\/login/,
          /\/logout/,
          /\/auth/,
          /\/api.*\/auth/,
          /\/profile/,
          /\/settings/,
          /\/password/,
          /\/reset/,
          /\/verify/,
          /\/payment/,
          /\/billing/
        ]
        
        sensitive_patterns.any? { |pattern| request.path.match(pattern) }
      end
      
      private def apply_environment_specific_headers(response : Http::Response)
        case @environment.downcase
        when "development"
          # More permissive headers for development
          response.headers["X-Debug-Mode"] = "true" if @custom_headers["X-Debug-Mode"]?
          
        when "staging"
          # Staging-specific headers
          response.headers["X-Environment"] = "staging"
          response.headers["X-Robots-Tag"] = "noindex, nofollow"
          
        when "production"
          # Production hardening
          response.headers["X-Content-Type-Options"] = "nosniff"
          response.headers["X-Download-Options"] = "noopen"
          response.headers["X-Permitted-Cross-Domain-Policies"] = "none"
          
          # Remove any debug headers
          response.headers.delete("X-Debug-Mode")
          response.headers.delete("X-Environment")
        end
      end
      
      # Preset configurations
      def self.strict_security(environment : String = "production") : SecureHeaders
        new(
          force_https: true,
          hsts_max_age: 63072000, # 2 years
          hsts_include_subdomains: true,
          hsts_preload: true,
          content_type_nosniff: true,
          frame_options: "DENY",
          xss_protection: "1; mode=block",
          referrer_policy: "strict-origin-when-cross-origin",
          content_security_policy: strict_csp_policy,
          cross_origin_embedder_policy: "require-corp",
          cross_origin_opener_policy: "same-origin",
          cross_origin_resource_policy: "same-origin",
          expect_certificate_transparency: true,
          environment: environment
        )
      end
      
      def self.moderate_security(environment : String = "production") : SecureHeaders
        new(
          force_https: true,
          hsts_max_age: 31536000, # 1 year
          hsts_include_subdomains: true,
          content_type_nosniff: true,
          frame_options: "SAMEORIGIN",
          xss_protection: "1; mode=block",
          referrer_policy: "strict-origin-when-cross-origin",
          content_security_policy: moderate_csp_policy,
          cross_origin_resource_policy: "cross-origin",
          environment: environment
        )
      end
      
      def self.development_security : SecureHeaders
        new(
          force_https: false,
          hsts_max_age: nil,
          content_type_nosniff: true,
          frame_options: "SAMEORIGIN",
          xss_protection: "1; mode=block",
          referrer_policy: "strict-origin-when-cross-origin",
          content_security_policy: development_csp_policy,
          environment: "development"
        )
      end
      
      private def self.strict_csp_policy : String
        [
          "default-src 'self'",
          "script-src 'self'",
          "style-src 'self' 'unsafe-inline'",
          "img-src 'self' data:",
          "font-src 'self'",
          "connect-src 'self'",
          "frame-src 'none'",
          "object-src 'none'",
          "base-uri 'self'",
          "form-action 'self'",
          "frame-ancestors 'none'",
          "upgrade-insecure-requests",
          "block-all-mixed-content"
        ].join("; ")
      end
      
      private def self.moderate_csp_policy : String
        [
          "default-src 'self'",
          "script-src 'self' 'unsafe-inline'",
          "style-src 'self' 'unsafe-inline'",
          "img-src 'self' data: https:",
          "font-src 'self' https:",
          "connect-src 'self'",
          "frame-src 'self'",
          "object-src 'none'",
          "base-uri 'self'",
          "form-action 'self'",
          "upgrade-insecure-requests"
        ].join("; ")
      end
      
      private def self.development_csp_policy : String
        [
          "default-src 'self' 'unsafe-eval' 'unsafe-inline'",
          "script-src 'self' 'unsafe-eval' 'unsafe-inline'",
          "style-src 'self' 'unsafe-inline'",
          "img-src 'self' data: blob:",
          "font-src 'self' data:",
          "connect-src 'self' ws: wss:",
          "frame-src 'self'",
          "object-src 'none'"
        ].join("; ")
      end
    end
    
    # Security Headers helper methods for controllers
    module SecureHeadersHelpers
      def add_security_header(name : String, value : String)
        response.headers[name] = value
      end
      
      def set_content_security_policy(policy : String, report_only : Bool = false)
        header_name = report_only ? "Content-Security-Policy-Report-Only" : "Content-Security-Policy"
        response.headers[header_name] = policy
      end
      
      def set_cache_control(directive : String)
        response.headers["Cache-Control"] = directive
      end
      
      def prevent_caching
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
      end
      
      def allow_framing(policy : String = "SAMEORIGIN")
        response.headers["X-Frame-Options"] = policy
      end
      
      def deny_framing
        response.headers["X-Frame-Options"] = "DENY"
      end
      
      def set_referrer_policy(policy : String)
        response.headers["Referrer-Policy"] = policy
      end
      
      def require_secure_transport(max_age : Int32 = 31536000, include_subdomains : Bool = true)
        hsts_value = "max-age=#{max_age}"
        hsts_value += "; includeSubDomains" if include_subdomains
        response.headers["Strict-Transport-Security"] = hsts_value
      end
      
      def set_permissions_policy(policy : String)
        response.headers["Permissions-Policy"] = policy
      end
      
      def disable_feature(feature : String)
        current = response.headers["Permissions-Policy"]?
        if current
          response.headers["Permissions-Policy"] = "#{current}, #{feature}=()"
        else
          response.headers["Permissions-Policy"] = "#{feature}=()"
        end
      end
      
      def enable_feature_for_self(feature : String)
        current = response.headers["Permissions-Policy"]?
        if current
          response.headers["Permissions-Policy"] = "#{current}, #{feature}=(self)"
        else
          response.headers["Permissions-Policy"] = "#{feature}=(self)"
        end
      end
      
      def set_cross_origin_policies(embedder : String? = nil, opener : String? = nil, resource : String? = nil)
        response.headers["Cross-Origin-Embedder-Policy"] = embedder if embedder
        response.headers["Cross-Origin-Opener-Policy"] = opener if opener
        response.headers["Cross-Origin-Resource-Policy"] = resource if resource
      end
      
      def isolate_origin
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
      end
      
      def add_security_report_endpoint(endpoint : String)
        report_to = {
          group: "default",
          max_age: 31536000,
          endpoints: [{url: endpoint}]
        }
        
        response.headers["Report-To"] = report_to.to_json
      end
      
      def remove_server_headers
        response.headers.delete("Server")
        response.headers.delete("X-Powered-By")
        response.headers.delete("X-AspNet-Version")
        response.headers.delete("X-AspNetMvc-Version")
      end
    end
    
    # Security audit helper
    class SecurityAudit
      @headers : ::HTTP::Headers
      @request_url : String
      @is_https : Bool
      
      def initialize(@headers : ::HTTP::Headers, @request_url : String, @is_https : Bool)
      end
      
      def audit : Hash(String, Hash(String, String | Bool))
        results = Hash(String, Hash(String, String | Bool)).new
        
        results["transport_security"] = audit_transport_security
        results["content_security"] = audit_content_security
        results["frame_security"] = audit_frame_security
        results["xss_protection"] = audit_xss_protection
        results["content_type"] = audit_content_type
        results["referrer_policy"] = audit_referrer_policy
        results["cross_origin"] = audit_cross_origin_policies
        results["cache_control"] = audit_cache_control
        results["information_disclosure"] = audit_information_disclosure
        
        results
      end
      
      def security_score : Int32
        audit_results = audit
        total_checks = 0
        passed_checks = 0
        
        audit_results.each do |category, checks|
          checks.each do |check, result|
            total_checks += 1
            passed_checks += 1 if result.is_a?(Bool) && result
          end
        end
        
        return 0 if total_checks == 0
        (passed_checks * 100 / total_checks).to_i32
      end
      
      private def audit_transport_security : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        results["https_enabled"] = @is_https
        
        hsts_header = @headers["Strict-Transport-Security"]?
        results["hsts_enabled"] = !hsts_header.nil?
        
        if hsts_header
          results["hsts_max_age_sufficient"] = hsts_header.includes?("max-age=") && 
                                              extract_max_age(hsts_header) >= 31536000
          results["hsts_include_subdomains"] = hsts_header.includes?("includeSubDomains")
          results["hsts_preload"] = hsts_header.includes?("preload")
        end
        
        results
      end
      
      private def audit_content_security : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        csp_header = @headers["Content-Security-Policy"]?
        results["csp_enabled"] = !csp_header.nil?
        
        if csp_header
          results["csp_default_src_restricted"] = !csp_header.includes?("default-src *") &&
                                                 !csp_header.includes?("default-src 'unsafe-inline'")
          results["csp_script_src_safe"] = !csp_header.includes?("script-src 'unsafe-eval'") ||
                                          csp_header.includes?("'nonce-")
          results["csp_blocks_mixed_content"] = csp_header.includes?("block-all-mixed-content") ||
                                               csp_header.includes?("upgrade-insecure-requests")
        end
        
        results
      end
      
      private def audit_frame_security : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        frame_options = @headers["X-Frame-Options"]?
        results["frame_options_set"] = !frame_options.nil?
        results["frame_options_secure"] = frame_options == "DENY" || frame_options == "SAMEORIGIN"
        
        results
      end
      
      private def audit_xss_protection : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        xss_protection = @headers["X-XSS-Protection"]?
        results["xss_protection_enabled"] = xss_protection == "1; mode=block"
        
        results
      end
      
      private def audit_content_type : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        content_type_options = @headers["X-Content-Type-Options"]?
        results["content_type_nosniff"] = content_type_options == "nosniff"
        
        results
      end
      
      private def audit_referrer_policy : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        referrer_policy = @headers["Referrer-Policy"]?
        results["referrer_policy_set"] = !referrer_policy.nil?
        
        secure_policies = [
          "no-referrer",
          "same-origin", 
          "strict-origin",
          "strict-origin-when-cross-origin"
        ]
        
        results["referrer_policy_secure"] = referrer_policy && 
                                           secure_policies.includes?(referrer_policy)
        
        results
      end
      
      private def audit_cross_origin_policies : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        coep = @headers["Cross-Origin-Embedder-Policy"]?
        coop = @headers["Cross-Origin-Opener-Policy"]?
        corp = @headers["Cross-Origin-Resource-Policy"]?
        
        results["cross_origin_embedder_policy_set"] = !coep.nil?
        results["cross_origin_opener_policy_set"] = !coop.nil?
        results["cross_origin_resource_policy_set"] = !corp.nil?
        
        results
      end
      
      private def audit_cache_control : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        cache_control = @headers["Cache-Control"]?
        
        # Check if sensitive routes have proper cache control
        is_sensitive = @request_url.includes?("login") || 
                      @request_url.includes?("admin") ||
                      @request_url.includes?("auth")
        
        if is_sensitive
          results["sensitive_route_no_cache"] = cache_control && 
                                               cache_control.includes?("no-store")
        else
          results["cache_control_set"] = !cache_control.nil?
        end
        
        results
      end
      
      private def audit_information_disclosure : Hash(String, String | Bool)
        results = Hash(String, String | Bool).new
        
        # Check for information-disclosing headers
        results["server_header_removed"] = @headers["Server"]?.nil?
        results["powered_by_header_removed"] = @headers["X-Powered-By"]?.nil?
        results["aspnet_version_removed"] = @headers["X-AspNet-Version"]?.nil?
        
        results
      end
      
      private def extract_max_age(hsts_header : String) : Int32
        match = hsts_header.match(/max-age=(\d+)/)
        return 0 unless match
        
        match[1].to_i32
      rescue
        0
      end
    end
  end
end