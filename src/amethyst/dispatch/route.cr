class Route
  getter :pattern
  getter :controller
  getter :action
  getter :length
  getter :methods

  def initialize(@pattern, @controller, @action)
    @pattern = @pattern.gsub(/\/$/, "\$") unless @pattern == "/"
    @length  = @pattern.split("/").length
    @methods = [] of String
  end

  # Adds a HTTP request method for route to respond to
  def add_request_method(method : String)
    raise Exceptions::UnsupportedHttpMethod.new(method) unless Http::METHODS.includes?(method)
    @methods << method
  end

  # Cheks whether path matches a route pattern and HTTP method
  def matches?(path, method)
    raise Exceptions::HttpNotImplemented.new(method) unless Http::METHODS.includes?(method)
    path = path.gsub(/\/$/, "") unless path == "/"
    return false unless path.split("/").length == @length
    regex = Regex.new(@pattern.to_s.gsub(/(:\w*)/, ".*"))
    matches = false
    if path.match(regex)
      raise Exceptions::HttpMethodNotAllowed.new(method, @methods) unless @methods.includes?(method)
      matches = true
    end
    matches
  end

  # Returns hash of params of given path
  def params(path)
    params        = {} of String => String
    path_items    = path.split("/")
    pattern_items = @pattern.split("/")
    path_items.length.times do |i|
      if pattern_items[i].match(/(:\w*)/)
        params[pattern_items[i].gsub(/:/, "")] = path_items[i]
      end
    end
    return params
  end
end

# TODO: Create separate module for Exceptions
# TODO: Implement own to_s method
