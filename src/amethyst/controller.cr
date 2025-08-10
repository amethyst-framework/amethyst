require "json"
require "uri"

module Amethyst
  # Modern controller with type safety and minimal boilerplate
  class Controller
    @request : Http::Request?
    @response : Http::Response?
    @params : Hash(String, String)?
    @query_params : Hash(String, String)?
    @body_params : Hash(String, String | JSON::Any)?
    
    def request
      @request.not_nil!
    end
    
    def response
      @response ||= Http::Response.new
    end
    
    def params
      @params ||= {} of String => String
    end
    
    def query_params
      @query_params ||= parse_query_params
    end
    
    def body_params
      @body_params ||= parse_body_params
    end
    
    def set_request(req : Http::Request)
      @request = req
    end
    
    def set_params(p : Hash(String, String))
      @params = p
    end
    
    def initialize
    end
    
    # Type-safe JSON response
    def json(data, status : Int32 = 200) : Http::Response
      Http::Response.new(status, data.to_json, ::HTTP::Headers{"Content-Type" => "application/json"})
    end
    
    # HTML response
    def html(content : String, status : Int32 = 200) : Http::Response
      Http::Response.new(status, content, ::HTTP::Headers{"Content-Type" => "text/html"})
    end
    
    # Plain text response
    def text(content : String, status : Int32 = 200) : Http::Response
      Http::Response.new(status, content, ::HTTP::Headers{"Content-Type" => "text/plain"})
    end
    
    # Redirect response
    def redirect(location : String, status : Int32 = 302) : Http::Response
      Http::Response.new(status, "", ::HTTP::Headers{"Location" => location})
    end
    
    # Halt execution with response
    def halt(status : Int32, message : String = "") : Http::Response
      Http::Response.new(status, message)
    end
    
    # Helper to respond based on Accept header
    def respond_to(&block)
      accept = request.headers["Accept"]? || "application/json"
      
      format_handler = FormatHandler.new(self, accept)
      yield format_handler
      format_handler.response
    end
    
    private def parse_query_params : Hash(String, String)
      return {} of String => String unless req = @request
      return {} of String => String unless query = req.query_string
      
      params = {} of String => String
      query.split("&").each do |pair|
        key, value = pair.split("=", 2)
        params[URI.decode(key)] = URI.decode(value || "")
      end
      params
    end
    
    private def parse_body_params : Hash(String, String | JSON::Any)
      return {} of String => String | JSON::Any unless req = @request
      return {} of String => String | JSON::Any unless body = req.body
      
      content_type = req.headers["Content-Type"]? || ""
      
      if content_type.includes?("application/json")
        body_str = body.is_a?(String) ? body : body.gets_to_end
        JSON.parse(body_str).as_h
      elsif content_type.includes?("application/x-www-form-urlencoded")
        params = {} of String => String | JSON::Any
        body_str = body.is_a?(String) ? body : body.gets_to_end
        body_str.split("&").each do |pair|
          key, value = pair.split("=", 2)
          params[URI.decode(key)] = URI.decode(value || "")
        end
        params
      else
        {} of String => String | JSON::Any
      end
    end
    
    # Format handler for respond_to
    class FormatHandler
      @controller : Controller
      @accept : String
      @response : Http::Response?
      
      def initialize(@controller, @accept)
      end
      
      def json(&block)
        if @accept.includes?("application/json") && !@response
          @response = yield
        end
      end
      
      def html(&block)
        if @accept.includes?("text/html") && !@response
          @response = yield
        end
      end
      
      def response
        @response || @controller.json({error: "Not Acceptable"}, 406)
      end
    end
  end
  
  # Params validator for strong parameters
  class ParamValidator
    @params : Hash(String, String | JSON::Any)
    
    def initialize(params : Hash(String, String))
      @params = {} of String => String | JSON::Any
      params.each { |k, v| @params[k] = v }
    end
    
    def initialize(@params : Hash(String, String | JSON::Any))
    end
    
    def require(key : String) : String | JSON::Any
      @params[key]? || raise MissingParameterError.new(key)
    end
    
    def string(key : String, default : String? = nil) : String
      value = @params[key]?
      return default.not_nil! if value.nil? && default
      value.to_s
    end
    
    def int(key : String, default : Int32? = nil, min : Int32? = nil, max : Int32? = nil) : Int32
      value = @params[key]?
      return default.not_nil! if value.nil? && default
      
      int_value = value.to_s.to_i
      
      if min && int_value < min
        raise InvalidParameterError.new(key, "must be >= #{min}")
      end
      
      if max && int_value > max
        raise InvalidParameterError.new(key, "must be <= #{max}")
      end
      
      int_value
    end
    
    def bool(key : String, default : Bool? = nil) : Bool
      value = @params[key]?
      return default.not_nil! if value.nil? && default
      
      value.to_s.downcase.in?("true", "1", "yes")
    end
    
    def float(key : String, default : Float64? = nil) : Float64
      value = @params[key]?
      return default.not_nil! if value.nil? && default
      value.to_s.to_f
    end
    
    def array(key : String, delimiter : String = ",") : Array(String)
      value = @params[key]?
      return [] of String if value.nil?
      value.to_s.split(delimiter).map(&.strip)
    end
    
    def json(key : String) : JSON::Any
      value = @params[key]?
      return JSON::Any.new({} of String => JSON::Any) if value.nil?
      
      if value.is_a?(JSON::Any)
        value
      else
        JSON.parse(value.to_s)
      end
    end
  end
  
  # Exceptions
  class MissingParameterError < Exception
    def initialize(param : String)
      super("Required parameter '#{param}' is missing")
    end
  end
  
  class InvalidParameterError < Exception
    def initialize(param : String, message : String)
      super("Parameter '#{param}' #{message}")
    end
  end
end