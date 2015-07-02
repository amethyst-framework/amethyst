class Router
  getter :routes
  getter :controllers
  getter :matched_route

  include Support::RoutesPainter
  include Sugar::Klass
  singleton_INSTANCE

  # This macro is a hack that allows to instansiate controllers through
  # @controllers.fetch("ControllerName").new
  macro register_controller(klass_name)
    @controllers["#{{{klass_name.id}}}"] = {{klass_name.id}}
  end

  def initialize()
    @routes      = [] of Dispatch::Route
    @controllers = {} of String => Base::Controller.class
    @matched_route :: Dispatch::Route
    @controllers_instances = {} of String => Base::Controller
  end

  # Adds controller to hash @controllers and make it available for app
  def register(controller)
    register_controller controller
  end

  # It allows to 'draw' routes like you can do in Rails routes.rb
  def draw(&block)
    with self yield
  end

  # Return true if path route exists, and sets @matched_route
  def exists?(path, method)
    raise Exceptions::HttpNotImplemented.new(method) unless Http::METHODS.includes?(method)
    exists = false
    @routes.each do |route|
      if route.matches?(path, method)
        exists = true
        @matched_route = route
        break
      end
    end
    exists
  end

  # Process regular routes (which are in @routes)
  def process_named_route(request : Http::Request, response : Http::Response)
    controller = @matched_route.controller
    controller_instance = @controllers_instances[controller] ||=  @controllers.fetch(controller).new
    controller_instance.set_env(request, response)
    response = @controllers_instances[controller].call_action(@matched_route.action)
  end

  def process_default_route(request : Http::Request, response : Http::Response)
    regexp = "^\/(?<controller>[a-z]*)\/(?<action>[a-z,_,-]*)"
    match = Regex.new(regexp).match(request.path)
    if match
      controller = match["controller"] as String
      action     = match["action"]     as String
      controller = Base::App.settings.namespace+controller.capitalize+"Controller"
      if @controllers.has_key? controller
        controller_instance = @controllers_instances[controller] ||=  @controllers.fetch(controller).new
        controller_instance.set_env(request, response)
      end
      response = @controllers_instances[controller].call_action(action)
    else
      response
    end
  end

  # Actually, performs a routing
  def call(request : Http::Request) : Http::Response
    response = Http::Response.new(404, "Not found")
    if exists = exists? request.path, request.method
      response = process_named_route(request, response)
    else
      response = process_default_route(request, response)
    end
  end

  def to_s(io : IO)
    msg = "\n"
    @routes.each do |route|
      route.methods.each do |method|
        msg += "#{method} #{route.pattern} to: #{route.controller.capitalize}\##{route.action} \n"
      end
    end
    io << msg
  end
end
