class App
  property :port
  property :name
  getter   :routes
  getter   :app_dir

  def initialize(app_path= __FILE__, @port=8080)
    @name          = File.basename(app_path).gsub(/.\w+\Z/, "")
    Base::App.settings.app_dir  = File.dirname(app_path)
    @run_string    = "[Amethyst #{Time.now}] serving application \"#{@name}\" at http://127.0.0.1:#{port}" #TODO move to Logger class
    @http_handler  = Base::Handler.new
    Base::App.set_default_middleware
  end

  def self.settings
    Base::Config::INSTANCE
  end

  def self.routes
    Dispatch::Router::INSTANCE
  end

  def self.logger
    Base::Logger::INSTANCE
  end

  def self.use(middleware : Middleware::Base.class)
    Middleware::MiddlewareStack::INSTANCE.use middleware
  end

  def serve()
    puts @run_string
    server = HTTP::Server.new @port, @http_handler
    server.listen
  end

  def self.set_default_middleware
    use Middleware::Cookies
    if Base::App.settings.environment == "development"
       use Middleware::ShowExceptions
       use Middleware::HttpLogger
       use Middleware::TimeLogger
    end
    use Middleware::Static
  end
end

#TODO: Implement enviroments(production, development)
#TODO: Implement configuring app.configure(&block)