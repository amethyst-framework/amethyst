module Amethyst
  module Base
    class App
      property :port
      property name : String
      getter   :routes

      @app : Middleware::Base | Dispatch::Router
      @http_handler : Base::Handler

      def initialize(app_path, app_type={{@type.name.stringify}})
        @port = 8080
        @name = File.basename(app_path).gsub(/.\w+\Z/, "")
        self.class.settings.app_dir   = ENV["PWD"]
        self.class.settings.namespace = get_app_namespace(app_type)
        set_default_middleware
        @app = Middleware::MiddlewareStack.instance.build_middleware
        @http_handler  = Base::Handler.new(@app)
      end

      # Shortcut for Config
      def self.settings
        Base::Config.instance
      end

      # Shortcut for Router
      def self.routes
        Dispatch::Router.instance
      end

      # Shortcut for Logger instance
      def self.logger
        Base::Logger.instance
      end

      # Shortcut for Session Pool
      def self.session
        Session::Pool.instance
      end

      # Shortcut for MiddlewareStack instance
      def self.middleware
        Middleware::MiddlewareStack.instance
      end

      def self.use(middleware : Middleware::Base.class)
        self.middleware.use middleware
      end

      def serve(port=8080)
        host = "0.0.0.0"
        @port = port.to_i
        run_string = "[Amethyst #{VERSION}] serving application \"#{@name}\" at http://#{host}:#{@port}" #TODO move to Logger class
        puts run_string
        App.logger.log_string run_string
        server = HTTP::Server.new host, port, @http_handler
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
