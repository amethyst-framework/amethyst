require "cgi"

METHODS = %w(GET POST PUT DELETE)

class Request
  property :method
  property :headers
  property :body
  property :cookies
  getter   :version
  setter   :path

  include Support::HeaderHelper

  def initialize(base_request : HTTP::Request)
    @method  = base_request.method
    @path    = base_request.path
    @headers = base_request.headers
    @body    = base_request.body
    @version = base_request.version
    @query_parameters   = {} of String => String
    @path_parameters    = {} of String => String
    @request_parameters = {} of String => String
    @cookies = {} of String => String
    @accept = ""
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

  # returns "GET" parameters: '/index?user=Andrew&id=5'
  def query_parameters
    @query_parameters unless @query_parameters.empty?
    @query_parameters = parse_parameters query_string
  end

  # returns path parameters: '/users/:id'
  def path_parameters
    @path_parameters unless @path_parameters.empty?
    if Base::App.routes.exists? path, method
      @path_parameters = Base::App.routes.matched_route.params path
    end
    @path_parameters
  end

  # returns POST parameters
  def request_parameters
    if content_type == "application/x-www-form-urlencoded"
      @query_parameters = parse_parameters @body
    end
    @query_parameters
  end

  # For now, if '*/*' is specified, then 'html/text', else first type in the list will be returned
  # This is a workaround, need to be fixed in future
  def accept
    @accept unless @accept.empty?
    entries = headers["Accept"].split ","
    entries.map do |e|
      if e.includes? ";"
        e = e.split(";")[0]
      end
      e
    end
    if entries.includes? "*/*"
      @accept = "text/html"
    else
      @accept = entries.first
    end
    @accept
  end

  # Parses params from a given string
  private def parse_parameters(params_string)
    hash = {} of String => String
    params = params_string.to_s.split("&")
    params.each do |param|
      if match = /^(?<key>[^=]*)(=(?<value>.*))?$/.match(param)
        key, value = param.split("=").map { |s| CGI.unescape(s) }
        hash[key] = value
      end
    end
    hash
  end

  # Sets properties to log
  def log 
    {
      "http method"     : @method,
      "path"            : path,
      "query string"    : query_string,
      "protocol"        : protocol,
      "host"            : host,
      "port"            : port,
      "version"         : @version,
      "query params"    : query_parameters,
      "path parameters" : path_parameters,
      "post parameters" : request_parameters,
      "content type"    : content_type
    }
  end
end

# TODO: Improve Request class, add @env like in Rails
