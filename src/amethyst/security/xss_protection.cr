require "html"
require "json"

module Amethyst
  module Security
    # XSS Protection middleware
    class XSSProtection < Middleware::Base
      @auto_escape_html : Bool
      @sanitize_json_responses : Bool
      @content_type_nosniff : Bool
      @xss_filter : Bool
      @frame_options : String?
      @content_security_policy : String?
      @sanitization_rules : Hash(String, Array(String))
      @allowed_tags : Set(String)
      @allowed_attributes : Hash(String, Array(String))
      @url_schemes : Set(String)
      @dangerous_protocols : Set(String)
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @auto_escape_html = true
        @sanitize_json_responses = true
        @content_type_nosniff = true
        @xss_filter = true
        @frame_options = "DENY"
        @content_security_policy = "default-src 'self'"
        
        @sanitization_rules = default_sanitization_rules
        @allowed_tags = Set{"p", "br", "strong", "em", "u", "i", "a", "ul", "ol", "li", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "code", "pre"}
        @allowed_attributes = {
          "a" => ["href", "title"],
          "*" => ["class", "id"]
        }
        @url_schemes = Set{"http", "https", "mailto", "tel"}
        @dangerous_protocols = Set{"javascript", "data", "vbscript", "file", "about"}
      end
      
      def call(request) : Http::Response
        # Process request for potential XSS attacks
        sanitized_request = sanitize_request(request)
        
        response = @app.call(sanitized_request)
        
        # Add XSS protection headers and sanitize response
        protect_response(response)
      end
      
      def sanitize_html(html : String) : String
        return html unless @auto_escape_html
        
        # Remove dangerous protocols
        html = remove_dangerous_protocols(html)
        
        # Sanitize HTML tags and attributes
        sanitized = sanitize_html_content(html)
        
        # Escape remaining content
        HTML.escape(sanitized)
      end
      
      def sanitize_user_input(input : String) : String
        return input if input.empty?
        
        # Remove null bytes
        input = input.gsub("\0", "")
        
        # Remove or encode dangerous characters
        input = input.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi, "")
        input = input.gsub(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/mi, "")
        input = input.gsub(/javascript:/i, "removed:")
        input = input.gsub(/vbscript:/i, "removed:")
        input = input.gsub(/data:/i, "removed:")
        input = input.gsub(/on\w+\s*=/i, "data-removed=")
        
        # Encode HTML entities
        HTML.escape(input)
      end
      
      def sanitize_json_string(json_str : String) : String
        return json_str unless @sanitize_json_responses
        
        begin
          parsed = JSON.parse(json_str)
          sanitized = sanitize_json_recursive(parsed)
          sanitized.to_json
        rescue JSON::ParseException
          # If it's not valid JSON, treat as regular string
          sanitize_user_input(json_str)
        end
      end
      
      def validate_url(url : String) : Bool
        return false if url.empty?
        
        begin
          uri = URI.parse(url)
          scheme = uri.scheme
          
          return false unless scheme
          return false if @dangerous_protocols.includes?(scheme.downcase)
          
          @url_schemes.includes?(scheme.downcase)
        rescue
          false
        end
      end
      
      def content_security_policy_nonce : String
        Random::Secure.hex(16)
      end
      
      private def sanitize_request(request : Http::Request) : Http::Request
        # Sanitize query parameters
        if query = request.query
          sanitized_query = sanitize_query_string(query)
          # Create new request with sanitized query - simplified approach
          request
        end
        
        # Sanitize request body if it exists
        if body = request.body
          case request.headers["Content-Type"]?
          when .try(&.includes?("application/json"))
            sanitized_body = sanitize_json_string(body.to_s)
            # In practice, you'd create a new request with sanitized body
          when .try(&.includes?("application/x-www-form-urlencoded"))
            sanitized_body = sanitize_form_data(body.to_s)
          end
        end
        
        request
      end
      
      private def sanitize_query_string(query : String) : String
        params = query.split("&").map do |param|
          if param.includes?("=")
            key, value = param.split("=", 2)
            "#{URI.encode_www_form(key)}=#{URI.encode_www_form(sanitize_user_input(URI.decode_www_form(value)))}"
          else
            URI.encode_www_form(sanitize_user_input(URI.decode_www_form(param)))
          end
        end
        
        params.join("&")
      end
      
      private def sanitize_form_data(form_data : String) : String
        params = form_data.split("&").map do |param|
          if param.includes?("=")
            key, value = param.split("=", 2)
            "#{URI.encode_www_form(key)}=#{URI.encode_www_form(sanitize_user_input(URI.decode_www_form(value)))}"
          else
            URI.encode_www_form(sanitize_user_input(URI.decode_www_form(param)))
          end
        end
        
        params.join("&")
      end
      
      private def protect_response(response : Http::Response) : Http::Response
        # Add XSS protection headers
        if @xss_filter
          response.headers["X-XSS-Protection"] = "1; mode=block"
        end
        
        if @content_type_nosniff
          response.headers["X-Content-Type-Options"] = "nosniff"
        end
        
        if frame_options = @frame_options
          response.headers["X-Frame-Options"] = frame_options
        end
        
        if csp = @content_security_policy
          nonce = content_security_policy_nonce
          csp_with_nonce = csp.gsub("'nonce'", "'nonce-#{nonce}'")
          response.headers["Content-Security-Policy"] = csp_with_nonce
          response.headers["X-CSP-Nonce"] = nonce
        end
        
        # Sanitize response body based on content type
        if body = response.body
          content_type = response.headers["Content-Type"]?
          
          case content_type
          when .try(&.includes?("text/html"))
            response.body = sanitize_html(body.to_s)
          when .try(&.includes?("application/json"))
            response.body = sanitize_json_string(body.to_s)
          end
        end
        
        response
      end
      
      private def sanitize_html_content(html : String) : String
        # Simple HTML sanitization - remove dangerous tags and attributes
        sanitized = html
        
        # Remove script tags and their content
        sanitized = sanitized.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi, "")
        
        # Remove dangerous tags
        dangerous_tags = ["script", "iframe", "object", "embed", "applet", "form", "input", "button", "textarea", "select", "option"]
        dangerous_tags.each do |tag|
          sanitized = sanitized.gsub(/<\/?#{tag}\b[^>]*>/mi, "")
        end
        
        # Remove dangerous attributes
        sanitized = sanitized.gsub(/\bon\w+\s*=\s*["'][^"']*["']/i, "")
        sanitized = sanitized.gsub(/\bon\w+\s*=\s*[^>\s]*/i, "")
        
        # Remove style attributes that could contain javascript
        sanitized = sanitized.gsub(/\bstyle\s*=\s*["'][^"']*javascript[^"']*["']/i, "")
        
        sanitized
      end
      
      private def sanitize_json_recursive(json : JSON::Any) : JSON::Any
        case json.raw
        when String
          JSON::Any.new(sanitize_user_input(json.as_s))
        when Hash
          sanitized_hash = json.as_h.transform_values do |value|
            sanitize_json_recursive(value)
          end
          JSON::Any.new(sanitized_hash)
        when Array
          sanitized_array = json.as_a.map do |item|
            sanitize_json_recursive(item)
          end
          JSON::Any.new(sanitized_array)
        else
          json
        end
      end
      
      private def remove_dangerous_protocols(html : String) : String
        @dangerous_protocols.each do |protocol|
          html = html.gsub(/#{protocol}:/i, "removed:")
        end
        html
      end
      
      private def default_sanitization_rules : Hash(String, Array(String))
        {
          "remove_tags" => ["script", "iframe", "object", "embed", "applet", "form"],
          "remove_attributes" => ["onclick", "onload", "onerror", "onmouseover", "onfocus", "onblur"],
          "remove_protocols" => ["javascript", "vbscript", "data", "file"]
        }
      end
    end
    
    # XSS Helper methods for controllers and views
    module XSSHelpers
      def h(text : String) : String
        HTML.escape(text)
      end
      
      def html_escape(text : String) : String
        HTML.escape(text)
      end
      
      def sanitize(text : String) : String
        # Get XSS protection middleware instance
        xss_middleware = find_xss_middleware
        return HTML.escape(text) unless xss_middleware
        
        xss_middleware.sanitize_user_input(text)
      end
      
      def sanitize_html(html : String) : String
        xss_middleware = find_xss_middleware
        return HTML.escape(html) unless xss_middleware
        
        xss_middleware.sanitize_html(html)
      end
      
      def safe_url?(url : String) : Bool
        xss_middleware = find_xss_middleware
        return false unless xss_middleware
        
        xss_middleware.validate_url(url)
      end
      
      def link_to(text : String, url : String, **attributes) : String
        return "" unless safe_url?(url)
        
        escaped_text = html_escape(text)
        escaped_url = html_escape(url)
        attrs = build_link_attributes(attributes)
        
        %(<a href="#{escaped_url}"#{attrs}>#{escaped_text}</a>)
      end
      
      def image_tag(src : String, alt : String = "", **attributes) : String
        return "" unless safe_url?(src)
        
        escaped_src = html_escape(src)
        escaped_alt = html_escape(alt)
        attrs = build_image_attributes(attributes)
        
        %(<img src="#{escaped_src}" alt="#{escaped_alt}"#{attrs} />)
      end
      
      def content_tag(tag : String, content : String = "", **attributes) : String
        # Only allow safe tags
        safe_tags = Set{"div", "span", "p", "h1", "h2", "h3", "h4", "h5", "h6", "strong", "em", "br"}
        return "" unless safe_tags.includes?(tag)
        
        escaped_content = html_escape(content)
        attrs = build_tag_attributes(attributes)
        
        if content.empty?
          %(<#{tag}#{attrs} />)
        else
          %(<#{tag}#{attrs}>#{escaped_content}</#{tag}>)
        end
      end
      
      def javascript_tag(content : String, nonce : String? = nil) : String
        escaped_content = content.gsub(/<\/script>/i, "<\\/script>")
        nonce_attr = nonce ? %( nonce="#{html_escape(nonce)}") : ""
        
        %(<script#{nonce_attr}>#{escaped_content}</script>)
      end
      
      def style_tag(content : String, nonce : String? = nil) : String
        # Remove potentially dangerous CSS
        safe_content = content.gsub(/javascript:/i, "")
                             .gsub(/expression\(/i, "")
                             .gsub(/@import/i, "")
        
        nonce_attr = nonce ? %( nonce="#{html_escape(nonce)}") : ""
        
        %(<style#{nonce_attr}>#{safe_content}</style>)
      end
      
      private def find_xss_middleware : XSSProtection?
        # This would need to be implemented to find the XSS middleware instance
        # from the middleware stack - simplified for now
        nil
      end
      
      private def build_link_attributes(attributes : Hash) : String
        safe_attributes = ["class", "id", "target", "title", "rel"]
        build_html_attributes(attributes, safe_attributes)
      end
      
      private def build_image_attributes(attributes : Hash) : String
        safe_attributes = ["class", "id", "width", "height", "title", "loading"]
        build_html_attributes(attributes, safe_attributes)
      end
      
      private def build_tag_attributes(attributes : Hash) : String
        safe_attributes = ["class", "id", "data-*", "aria-*"]
        build_html_attributes(attributes, safe_attributes)
      end
      
      private def build_html_attributes(attributes : Hash, allowed : Array(String)) : String
        return "" if attributes.empty?
        
        attrs = attributes.compact_map do |key, value|
          key_str = key.to_s
          
          # Check if attribute is allowed
          is_allowed = allowed.any? do |pattern|
            if pattern.ends_with?("*")
              key_str.starts_with?(pattern[0..-2])
            else
              key_str == pattern
            end
          end
          
          next unless is_allowed
          
          %( #{key_str}="#{html_escape(value.to_s)}")
        end
        
        attrs.join
      end
    end
    
    # Content Security Policy builder
    class CSPBuilder
      @directives : Hash(String, Array(String))
      
      def initialize
        @directives = Hash(String, Array(String)).new
      end
      
      def default_src(*sources : String) : CSPBuilder
        @directives["default-src"] = sources.to_a
        self
      end
      
      def script_src(*sources : String) : CSPBuilder
        @directives["script-src"] = sources.to_a
        self
      end
      
      def style_src(*sources : String) : CSPBuilder
        @directives["style-src"] = sources.to_a
        self
      end
      
      def img_src(*sources : String) : CSPBuilder
        @directives["img-src"] = sources.to_a
        self
      end
      
      def font_src(*sources : String) : CSPBuilder
        @directives["font-src"] = sources.to_a
        self
      end
      
      def connect_src(*sources : String) : CSPBuilder
        @directives["connect-src"] = sources.to_a
        self
      end
      
      def frame_src(*sources : String) : CSPBuilder
        @directives["frame-src"] = sources.to_a
        self
      end
      
      def object_src(*sources : String) : CSPBuilder
        @directives["object-src"] = sources.to_a
        self
      end
      
      def base_uri(*sources : String) : CSPBuilder
        @directives["base-uri"] = sources.to_a
        self
      end
      
      def form_action(*sources : String) : CSPBuilder
        @directives["form-action"] = sources.to_a
        self
      end
      
      def frame_ancestors(*sources : String) : CSPBuilder
        @directives["frame-ancestors"] = sources.to_a
        self
      end
      
      def report_uri(uri : String) : CSPBuilder
        @directives["report-uri"] = [uri]
        self
      end
      
      def report_to(group : String) : CSPBuilder
        @directives["report-to"] = [group]
        self
      end
      
      def upgrade_insecure_requests : CSPBuilder
        @directives["upgrade-insecure-requests"] = [] of String
        self
      end
      
      def build : String
        @directives.map do |directive, sources|
          if sources.empty?
            directive
          else
            "#{directive} #{sources.join(" ")}"
          end
        end.join("; ")
      end
      
      def self.strict_policy : String
        new
          .default_src("'self'")
          .script_src("'self'", "'unsafe-inline'")
          .style_src("'self'", "'unsafe-inline'")
          .img_src("'self'", "data:")
          .font_src("'self'")
          .connect_src("'self'")
          .frame_src("'none'")
          .object_src("'none'")
          .base_uri("'self'")
          .form_action("'self'")
          .frame_ancestors("'none'")
          .upgrade_insecure_requests
          .build
      end
      
      def self.development_policy : String
        new
          .default_src("'self'", "'unsafe-eval'", "'unsafe-inline'")
          .script_src("'self'", "'unsafe-eval'", "'unsafe-inline'")
          .style_src("'self'", "'unsafe-inline'")
          .img_src("'self'", "data:", "blob:")
          .font_src("'self'", "data:")
          .connect_src("'self'", "ws:", "wss:")
          .build
      end
    end
  end
end