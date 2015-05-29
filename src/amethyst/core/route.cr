class Route
  getter :pattern
  getter :controller
  getter :action
  getter :length
  getter :params

  def initialize(@pattern, @controller, @action)
    @pattern = @pattern.gsub(/\/$/, "") unless @pattern == "/"
    @length  = @pattern.split("/").length
  end

  # Partially, stolen from Moonshine
  # Cheks whether path matches a route pattern
  def matches?(path)
    return false unless path.split("/").length == @length
    regex = Regex.new(@pattern.to_s.gsub(/(:\w*)/, ".*"))
    path.match(regex) ? true : false
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