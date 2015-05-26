class Route

  def initialize(@pattern)
    @pattern = @pattern.gsub(/\/$/, "") unless @pattern == "/"
    @length = @pattern.split("/").length
  end

  def matches?(path)
    false if route.split("/").length != @length
    regex = Regex.new(@pattern.to_s.gsub(/(:\w*)/, ".*"))
    route.match(regex) ? true : false
  end

  def get_params(path)
    params = {} of String => String
    path_items = path.split("/")
    pattern_items = @pattern.split("/")
    path_items.length.times do |i|
      if pattern_items[i].match(/(:\w*)/)
        params[pattern_items[i].gsub(/:/, "")] = path_items[i]
      end
    end
    return params
  end
end