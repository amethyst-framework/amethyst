module RoutesPainter

  # Describes methods available in App.routes.draw block of router

  # Sets a route that should respond to GET HTTP method
  # The synopsis of arguments receive is Rails-like:
  # get "/products/:id", "products#show"
  # where 'products' is a controller named ProductsController, and "show" is it's action
  def get_controller_and_action(string : String)
    pattern.gsub(/\$/, "\$") unless pattern == "/"
    controller, action = controller_action.split("#")
    controller = controller.capitalize+"Controller"
    route = Dispatch::Route.new(pattern, controller, action)
  end

  def get(pattern, controller_action)
    get_controller_and_action(pattern)
    route.add_request_method("GET")
    @routes << route
  end

  def put(pattern, controller_action)
    get_controller_and_action(pattern)
    route.add_request_method("PUT")
    @routes << route
  end

  def post(pattern, controller_action)
    get_controller_and_action(pattern)
    route.add_request_method("POST")
    @routes << route
  end

  def delete(pattern, controller_action)
    get_controller_and_action(pattern)
    route.add_request_method("DELETE")
    @routes << route
  end

  def all(pattern, controller_action)
    get_controller_and_action(pattern)
    route.add_request_method("GET")
    route.add_request_method("POST")
    route.add_request_method("PUT")
    route.add_request_method("DELETE")
    @routes << route
  end
end
