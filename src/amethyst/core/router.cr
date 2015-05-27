class Router
  getter :routes
  getter :controllers

  macro add_to_hash(klass_name)
      @controllers[{{klass_name}}.to_s] = {{klass_name.id}}
  end

  def initialize()
    @routes = [] of Core::Route
    @controllers = {} of String => Class
  end

  def register(controller)
    
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
        controller_instanse = @controllers.fetch(route.controller).new
        p controller_instanse
      end
    end
  end
end