class Router
  getter :routes
  getter :controllers
  getter :matched_route

  include Support::RoutesPainter
  include Sugar::Klass
  singleton_INSTANCE

  # This macro is a hack that allows to instansiate controllers through 
  # @controllers.fetch("ControllerName")
  macro register_controller(klass_name)
    @controllers["{{klass_name.id}}"] = {{klass_name.id}}
  end

  def initialize()
    @routes      = [] of Dispatch::Route
    @controllers = {} of String => Base::Controller.class 
    @methods     = {} of String => Symbol
    @matched_route = Dispatch::Route.new("/not_found/", "HttpError", "404" )
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
    exists = false
    @routes.each do |route|
      if route.matches?(path, method)
        exists = true
        @matched_route = route
        break
      end
    end
    return exists
  end

  def process_named_route(request, response)
    controller = @matched_route.controller.capitalize+"Controller"
    controller_instance = @controllers_instances[controller] ||=  @controllers.fetch(controller).new
    controller_instance.set_env(request, response)
    response = @controllers_instances[controller].call_action(@matched_route.action)
  end

  # Actually, performs a routing 
  def call(request : Http::Request) : Http::Response
    response = Http::Response.new(404, "Not found")
    if exists? request.path, request.method
      response = process_named_route(request, response)
    end
    response
  end
end