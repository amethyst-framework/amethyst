class App
  property :port
  property :name
  getter   :routes
  getter   :app_dir

  def initialize(app_path= __FILE__)
    @port = 8080
    @name          = File.basename(app_path).gsub(/.\w+\Z/, "")
    self.class.settings.app_dir  = File.dirname(app_path)
    set_default_middleware
    @app = Middleware::MiddlewareStack::INSTANCE.build_middleware
    @http_handler  = Base::Handler.new(@app)
  end

  # Shortcut for Config
  def self.settings
    Base::Config::INSTANCE
  end

  # Shortcut for Router
  def self.routes
    Dispatch::Router::INSTANCE
  end

  # Shortcut for Logger instance
  def self.logger
    Base::Logger::INSTANCE
  end

  # Shortcut for MiddlewareStack instance
  def self.middlewares
    Middleware::MiddlewareStack::INSTANCE
  end

  def self.use(middleware : Middleware::Base.class)
    Middleware::MiddlewareStack::INSTANCE.use middleware
  end

  def serve(port=8080)
    @port = port
    run_string    = "[Amethyst #{VERSION}] serving application \"#{@name}\" at http://127.0.0.1:#{@port}" #TODO move to Logger class
    puts run_string
    server = HTTP::Server.new port, @http_handler
    server.listen
  end

  # Sets default middleware for app
  private def set_default_middleware
    self.class.use Middleware::Cookies
    if self.class.settings.environment == "development"
       self.class.use Middleware::ShowExceptions
       self.class.use Middleware::HttpLogger
       self.class.use Middleware::TimeLogger
    end
    self.class.use Middleware::Static
  end
end