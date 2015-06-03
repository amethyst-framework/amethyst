class App
  property :port
  property :name
  getter   :routes

  def initialize(name= __FILE__, @port=8080)
    @name          = File.basename(name).gsub(/.\w+\Z/, "")
    @run_string    = "[Amethyst #{Time.now}] serving application \"#{@name}\" at http://127.0.0.1:#{port}" #TODO move to Logger class
    @router        = Dispatch::Router.new
    @http_handler  = Base::Handler.new(@router)
    App.set_default_middleware
  end

  def self.settings
    Base::Config::INSTANCE
  end

  def routes
    @router
  end

  def self.use(middleware : Middleware::Base.class)
    Middleware::MiddlewareStack::INSTANCE.add middleware
  end

  def serve()
    puts @run_string
    server = HTTP::Server.new @port, @http_handler
    server.listen
  end

  def self.set_default_middleware
    if App.settings.environment == "development"
      use Middleware::HttpLogger
      use Middleware::TimeMiddleware
    end
  end
end

#TODO: Implement enviroments(production, development)
#TODO: Implement configuring app.configure(&block)
#TODO: Implement tracer module