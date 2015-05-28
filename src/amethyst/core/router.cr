class Router
  getter :routes
  getter :controllers

  macro register_controller(klass_name)
      @controllers[{{klass_name}}.to_s] = {{klass_name.id}}
  end

  def initialize()
    @routes      = [] of Core::Route
    @controllers = {} of String => Class
    @methods     = {} of String => Symbol
    @response = Http::Response.new(404, "Not found")
  end

  # Adds controller to hash @controllers
  def register(controller)
    register_controller controller
  end 

  # It allows to 'draw' routes like you can do in Rails routes.rb
  def draw(&block)
    with self yield
  end

  # Sets a route that should respond to GET HTTP method
  # The synopsis of arguments receive is Rails-like:
  # get "/products/:id", "products#show"
  # where 'products' is a controller named ProductsController, and "show" is it's action
  def get(pattern, controller_action)
    controller, action = controller_action.split("#")
    controller = controller.capitalize+"Controller"
    @routes << Route.new(pattern, controller, action)
  end

  def call(request : Http::Request)
    path  = request.path
    @routes.each do |route|
      if route.matches?(path)
        controller_instanse = @controllers.fetch(route.controller).new
        if controller_instanse.call_action(route.action, "request")
          @response = controller_instanse.call_action(route.action, "request")
        end
      end
    end
    return @response
  end
end