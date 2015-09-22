module Amethyst
  module Base
    class App
      property :port
      property :name
      getter   :routes

      def initialize(app_path= __FILE__, app_type={{@type.name.stringify}})
        @port = 8080
        @name = File.basename(app_path).gsub(/.\w+\Z/, "")
        self.class.settings.app_dir   = ENV["PWD"]
        self.class.settings.namespace = get_app_namespace(app_type)
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

      # Shortcut for Session Pool
      def self.session
        Session::Pool::INSTANCE
      end

      # Shortcut for MiddlewareStack instance
      def self.middleware
        Middleware::MiddlewareStack::INSTANCE
      end

      def self.use(middleware : Middleware::Base.class)
        self.middleware.use middleware
      end

      def serve(port=8080)
        @port = port.to_i
        run_string    = "[Amethyst #{VERSION}] serving application \"#{@name}\" at http://127.0.0.1:#{@port}" #TODO move to Logger class
        puts run_string
        App.logger.log_string run_string
        server = HTTP::Server.new port, @http_handler
        server.listen
      end

      private def get_app_namespace(app_type)
        if app_type == "<Program>"
          return ""
        end
        sep = "::"
        modules = app_type.split(sep)
        namespace = ""
        if modules.size > 1
          modules.delete(modules.last)
          namespace = modules.join(sep)+sep
        end
        namespace
      end

      # Sets default middleware for app
      private def set_default_middleware
        self.class.use Middleware::ShowExceptions
        if self.class.settings.environment == "development"
          self.class.use Middleware::HttpLogger
          self.class.use Middleware::TimeLogger
        end
        self.class.use Middleware::Session
        self.class.use Middleware::Static
      end
    end
  end
end
