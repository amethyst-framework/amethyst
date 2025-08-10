module Amethyst
  # Type-safe parameter extraction with automatic parsing and validation
  class Params
    @raw_params : Hash(String, String)
    @errors = {} of String => String
    
    def initialize(@raw_params)
    end
    
    # Get parameter with type conversion and optional default
    def get(name : String | Symbol, type : T.class, default : T? = nil) : T? forall T
      str_name = name.to_s
      value = @raw_params[str_name]?
      
      return default unless value
      
      parse_value(value, T)
    rescue ex
      @errors[str_name] = "Invalid #{T.name}: #{ex.message}"
      default
    end
    
    # Get required parameter - raises if missing or invalid
    def get!(name : String | Symbol, type : T.class) : T forall T
      str_name = name.to_s
      value = @raw_params[str_name]?
      
      raise MissingParameter.new(str_name) unless value
      
      parse_value(value, T)
    rescue ex : TypeCastError
      raise InvalidParameter.new(str_name, T.name, ex.message)
    end
    
    # Get parameter with block for custom handling
    def get(name : String | Symbol, type : T.class, &block : T ->) forall T
      if value = get(name, T)
        yield value
      end
    end
    
    # Require parameter with block
    def require(name : String | Symbol, type : T.class, &block : T ->) forall T
      value = get!(name, T)
      yield value
    end
    
    # Get multiple parameters as named tuple
    macro fetch(**params)
      {
        {% for key, type in params %}
          {{key}}: get!({{key.stringify}}, {{type}}),
        {% end %}
      }
    end
    
    # Check if parameter exists
    def has?(name : String | Symbol) : Bool
      @raw_params.has_key?(name.to_s)
    end
    
    # Get all parameters as hash
    def to_h : Hash(String, String)
      @raw_params
    end
    
    # Validation errors
    def errors : Hash(String, String)
      @errors
    end
    
    def valid? : Bool
      @errors.empty?
    end
    
    # Parse nested parameters (for JSON/form data)
    def nest(prefix : String) : Params
      nested = {} of String => String
      
      @raw_params.each do |key, value|
        if key.starts_with?("#{prefix}[") && key.ends_with?("]")
          nested_key = key.lchop("#{prefix}[").rchop("]")
          nested[nested_key] = value
        end
      end
      
      Params.new(nested)
    end
    
    # Allow array parameters
    def get_array(name : String | Symbol, type : T.class) : Array(T) forall T
      str_name = name.to_s
      values = [] of T
      
      # Handle both name[] and name[0], name[1] formats
      @raw_params.each do |key, value|
        if key == "#{str_name}[]" || key.matches?(/^#{str_name}\[\d+\]$/)
          if parsed = parse_value(value, T)
            values << parsed
          end
        end
      end
      
      values
    end
    
    private def parse_value(value : String, type : T.class) : T forall T
      case T
      when String.class
        value.as(T)
      when Int32.class
        value.to_i32.as(T)
      when Int64.class
        value.to_i64.as(T)
      when Float32.class
        value.to_f32.as(T)
      when Float64.class
        value.to_f64.as(T)
      when Bool.class
        parse_bool(value).as(T)
      when Time.class
        Time.parse_iso8601(value).as(T)
      when UUID.class
        UUID.new(value).as(T)
      else
        # Try JSON parsing for complex types
        T.from_json(value)
      end
    rescue ex
      raise TypeCastError.new("Cannot parse '#{value}' as #{T.name}: #{ex.message}")
    end
    
    private def parse_bool(value : String) : Bool
      case value.downcase
      when "true", "1", "yes", "on"
        true
      when "false", "0", "no", "off"
        false
      else
        raise TypeCastError.new("Cannot parse '#{value}' as Bool")
      end
    end
  end
  
  # Parameter-related exceptions
  class ParameterError < Exception; end
  
  class MissingParameter < ParameterError
    def initialize(name : String)
      super("Required parameter '#{name}' is missing")
    end
  end
  
  class InvalidParameter < ParameterError
    def initialize(name : String, expected_type : String, message : String)
      super("Parameter '#{name}' expected to be #{expected_type}: #{message}")
    end
  end
  
  class TypeCastError < Exception; end
  
  # Extension for ::HTTP::Request to provide params
  class ::HTTP::Request
    @params : Amethyst::Params?
    @query_params : Amethyst::Params?
    @body_params : Amethyst::Params?
    
    # Combined params from all sources (path, query, body)
    def params : Amethyst::Params
      @params ||= begin
        all_params = {} of String => String
        
        # Query parameters
        if query_params = query_params?
          all_params.merge!(query_params)
        end
        
        # Body parameters (form or JSON)
        if body_params = body_params?
          all_params.merge!(body_params.to_h)
        end
        
        # Path parameters (injected by router)
        if path_params = @path_params
          all_params.merge!(path_params)
        end
        
        Amethyst::Params.new(all_params)
      end
    end
    
    # Just query string parameters
    def query_params : Amethyst::Params
      @query_params ||= begin
        params = ::HTTP::Params.parse(query || "")
        hash = {} of String => String
        params.each do |key, value|
          hash[key] = value
        end
        Amethyst::Params.new(hash)
      end
    end
    
    # Just body parameters
    def body_params : Amethyst::Params?
      @body_params ||= parse_body_params
    end
    
    private def parse_body_params : Amethyst::Params?
      return nil unless body_io = body
      
      content_type = headers["Content-Type"]?
      return nil unless content_type
      
      body_string = body_io.gets_to_end
      body_io.rewind
      
      case content_type
      when .includes?("application/x-www-form-urlencoded")
        params = ::HTTP::Params.parse(body_string)
        hash = {} of String => String
        params.each { |k, v| hash[k] = v }
        Amethyst::Params.new(hash)
      when .includes?("application/json")
        json = JSON.parse(body_string)
        hash = flatten_json(json)
        Amethyst::Params.new(hash)
      else
        nil
      end
    rescue
      nil
    end
    
    private def flatten_json(json : JSON::Any, prefix = "") : Hash(String, String)
      hash = {} of String => String
      
      case json.raw
      when Hash
        json.as_h.each do |key, value|
          new_prefix = prefix.empty? ? key : "#{prefix}[#{key}]"
          hash.merge!(flatten_json(value, new_prefix))
        end
      when Array
        json.as_a.each_with_index do |value, index|
          new_prefix = "#{prefix}[#{index}]"
          hash.merge!(flatten_json(value, new_prefix))
        end
      else
        hash[prefix] = json.to_s
      end
      
      hash
    end
    
    # Inject path parameters from router
    def path_params=(params : Hash(String, String))
      @path_params = params
      @params = nil # Reset combined params cache
    end
  end
end