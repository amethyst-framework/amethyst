module Amethyst
  module Config
    # Security configuration with sensible defaults
    class SecurityConfig
      # CSRF Protection
      property csrf_enabled : Bool = true
      property csrf_secret_key : String = Random::Secure.hex(32)
      property csrf_token_name : String = "authenticity_token"
      property csrf_header_name : String = "X-CSRF-Token"
      property csrf_cookie_name : String = "_csrf_token"
      property csrf_session_key : String = "_csrf_token"
      property csrf_skip_routes : Set(String) = Set(String).new
      
      # XSS Protection
      property xss_enabled : Bool = true
      property xss_auto_escape_html : Bool = true
      property xss_sanitize_json : Bool = true
      property xss_content_type_nosniff : Bool = true
      property xss_frame_options : String = "DENY"
      property xss_content_security_policy : String = "default-src 'self'"
      
      # Rate Limiting
      property rate_limiting_enabled : Bool = true
      property rate_limit_requests_per_minute : Int32 = 100
      property rate_limit_requests_per_hour : Int32 = 1000
      property rate_limit_burst_size : Int32 = 10
      
      # SQL Injection Protection
      property sql_injection_enabled : Bool = true
      property sql_check_query_params : Bool = true
      property sql_check_form_data : Bool = true
      property sql_check_json_data : Bool = true
      property sql_max_param_length : Int32 = 1000
      
      # Secure Headers
      property secure_headers_enabled : Bool = true
      property force_https : Bool = false
      property hsts_max_age : Int32 = 31536000 # 1 year
      property hsts_include_subdomains : Bool = true
      property frame_options : String = "DENY"
      property content_type_nosniff : Bool = true
      
      # JWT
      property jwt_enabled : Bool = false
      property jwt_secret_key : String = Random::Secure.hex(64)
      property jwt_expiration_time : Time::Span = 1.hour
      property jwt_refresh_expiration : Time::Span = 7.days
      property jwt_algorithm : String = "HS256"
      property jwt_issuer : String? = nil
      property jwt_audience : String? = nil
      
      def self.development
        config = new
        config.force_https = false
        config.csrf_enabled = false  # Easier for development
        config.rate_limiting_enabled = false
        config
      end
      
      def self.production
        config = new
        config.force_https = true
        config
      end
      
      def self.testing
        config = new
        config.csrf_enabled = false
        config.rate_limiting_enabled = false
        config.secure_headers_enabled = false
        config
      end
      
      # Fluent configuration methods
      def csrf(enabled : Bool = true, secret_key : String? = nil, **options)
        @csrf_enabled = enabled
        @csrf_secret_key = secret_key if secret_key
        options.each { |key, value| 
          case key
          when :token_name then @csrf_token_name = value.as(String)
          when :header_name then @csrf_header_name = value.as(String)
          when :cookie_name then @csrf_cookie_name = value.as(String)
          when :skip_routes then @csrf_skip_routes = value.as(Set(String))
          end
        }
        self
      end
      
      def xss_protection(enabled : Bool = true, **options)
        @xss_enabled = enabled
        options.each { |key, value|
          case key
          when :auto_escape_html then @xss_auto_escape_html = value.as(Bool)
          when :sanitize_json then @xss_sanitize_json = value.as(Bool)
          when :frame_options then @xss_frame_options = value.as(String)
          when :content_security_policy then @xss_content_security_policy = value.as(String)
          end
        }
        self
      end
      
      def rate_limiting(enabled : Bool = true, **options)
        @rate_limiting_enabled = enabled
        options.each { |key, value|
          case key
          when :requests_per_minute then @rate_limit_requests_per_minute = value.as(Int32)
          when :requests_per_hour then @rate_limit_requests_per_hour = value.as(Int32)
          when :burst_size then @rate_limit_burst_size = value.as(Int32)
          end
        }
        self
      end
      
      def secure_headers(enabled : Bool = true, **options)
        @secure_headers_enabled = enabled
        options.each { |key, value|
          case key
          when :force_https then @force_https = value.as(Bool)
          when :hsts_max_age then @hsts_max_age = value.as(Int32)
          when :frame_options then @frame_options = value.as(String)
          end
        }
        self
      end
      
      def jwt_authentication(enabled : Bool = true, secret_key : String? = nil, **options)
        @jwt_enabled = enabled
        @jwt_secret_key = secret_key if secret_key
        options.each { |key, value|
          case key
          when :expiration_time then @jwt_expiration_time = value.as(Time::Span)
          when :refresh_expiration then @jwt_refresh_expiration = value.as(Time::Span)
          when :algorithm then @jwt_algorithm = value.as(String)
          when :issuer then @jwt_issuer = value.as(String?)
          when :audience then @jwt_audience = value.as(String?)
          end
        }
        self
      end
    end
  end
end