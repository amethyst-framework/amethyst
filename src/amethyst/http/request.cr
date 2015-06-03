METHODS = %w(GET POST PUT DELETE)

class Request
  property :method
  property :headers
  property :body
  property :path_parameters
  property :request_parameters
  property :query_parameters
  getter   :version
  setter   :path

  def initialize(base_request : HTTP::Request)
    @method  = base_request.method
    @path 	 = base_request.path
    @headers = base_request.headers
    @body 	 = base_request.body
    @version = base_request.version
    @query_params = {} of String => String
  end

  # Allows you to know the request method (get? post?, etc.)
  {% for method in Http::METHODS %}
    def {{method.id.downcase}}?
      @method == {{method}} ? true : false
    end
  {% end %}

  # Force path to always return a String
  def path
    return URI.parse(@path).path.to_s
  end

  # Returns path query string. If it doesn't exists, returns "nil"
  def query_string
    URI.parse(@path).query
  end

  def host
    URI.parse(@path).host
  end

  def protocol
    URI.parse(@path).scheme
  end

  def port
    URI.parse(@path).port
  end

  # Returns request parameters sent as a part of query
  def query_parameters
    return @query_params unless @query_params.empty?
    params = query_string.to_s.split("&")
    params.each do |param|
      key, value = param.split("=")
      @query_params[key] = value
    end
    @query_params
  end

  # Sets variables to log (with HttpLogger)
  def log 
    {
      "http method"  => @method,
      "path"         : path,
      "query string" : query_string,
      "protocol"     : protocol,
      "host"         : host,
      "port"         : port,
      "version"      : @version,
      "query params" : query_parameters
    }
  end
end

# TODO: Improve Request class, add @env like in Rails