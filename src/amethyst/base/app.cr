class App
  property :port
  property :name
  getter   :routes

  def initialize(name= __FILE__, @port=8080)
    @name          = File.basename(name).gsub(/.\w+\Z/, "")
    @run_string    = "[Amethyst #{Time.now}] serving application \"#{@name}\" at http://127.0.0.1:#{port}" #TODO move to Logger class
    @midware_stack = Base::MiddlewareStack.new
    @router        = Dispatch::Router.new
    @http_handler  = Base::Handler.new(@midware_stack, @router)
  end

  def self.settings 
    Base::Config.get 
  end

  def routes
    @router
  end

  def use(middleware : Base::Middleware)
    @midware_stack.add middleware
  end

  def serve()
    puts @run_string
    server = HTTP::Server.new @port, @http_handler
    server.listen
  end
end

#TODO: Implement enviroments(production, development)
#TODO: Implement configuring app.configure(&block)
#TODO: Implement tracer module