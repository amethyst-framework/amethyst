class Router
  getter :routes
  getter :controllers

  macro add_to_hash(klass_name)
      @controllers[{{klass_name}}.to_s] = {{klass_name.id}}
  end

  macro call_action(action)

  def initialize()
    @routes = [] of Core::Route
    @controllers = {} of String => Class
    @methods = {} of String => Symbols
  end

  def register(controller, *controller_actions)
    add_to_hash controller

  end 

  def draw(&block)
    with self yield
  end

  def get(pattern, controller_action)
    controller, action = controller_action.split("#")
    controller = controller.capitalize+"Controller"
    @routes << Route.new(pattern, controller, action)
  end

  def call(request)
    path  = request.path
    @routes.each do |route|
      if route.matches?(path)
        puts "works"
        controller_instanse = @controllers.fetch(route.controller).new(route.action)
        controller_instanse
      end
    end
  end
end