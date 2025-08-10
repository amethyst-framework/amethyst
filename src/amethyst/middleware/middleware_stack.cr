module Amethyst
  module Middleware
    class MiddlewareStack
      @middleware_instances : Hash(String, Middleware::Base)?

      # Sugar::Klass removed - using standard Crystal singleton
      @@instance : MiddlewareStack?
      
      def self.instance
        @@instance ||= new
      end
      include Enumerable(Class)

      def initialize()
        @middlewares   = [] of Middleware::Base.class
        @middleware_instances = nil
      end

      def build_middleware
        app = Amethyst::Routing::OptimizedRouter.instance
        @middlewares.reverse.each do |mdware|
          mdware = instantiate mdware
          app = mdware.build(app)
        end
        puts self if Amethyst::Base::App.settings.environment == "development"
        app
      end

      def use(middleware : Middleware::Base.class | Middleware::Base)
        case middleware
        when Middleware::Base.class
          @middlewares << middleware
        when Middleware::Base
          # Store instance directly - we'll handle this differently in build
          @middlewares << middleware.class
          @middleware_instances ||= {} of String => Middleware::Base
          @middleware_instances.not_nil![middleware.class.name] = middleware
        end
      end

      def each
        0.upto(@middlewares.length-1) do |i|
          yield @middlewares[i]
        end
      end

      def includes?(middleware)
        @middlewares.includes? middleware
      end

      def clear
        @middlewares.clear
      end
      
      private def instantiate(middleware_class : Middleware::Base.class)
        # Check if we have a pre-created instance
        if instances = @middleware_instances
          if instance = instances[middleware_class.name]?
            return instance
          end
        end
        
        # Create new instance using reflection to handle different constructor patterns
        case middleware_class.name
        when "Amethyst::Security::SecureHeaders"
          # Create with default security settings
          middleware_class.as(Security::SecureHeaders.class).new(nil)
        when "Amethyst::Security::XSSProtection"  
          # Create with default XSS settings
          middleware_class.as(Security::XSSProtection.class).new(nil)
        when "Amethyst::Security::SQLInjectionProtection"
          # Create with default SQL injection settings
          middleware_class.as(Security::SQLInjectionProtection.class).new(nil)
        when "Amethyst::Security::CSRFProtection"
          # Create with default CSRF settings
          middleware_class.as(Security::CSRFProtection.class).new(nil, nil)
        else
          # For all other middleware, use single-parameter constructor
          middleware_class.new(nil)
        end
      end

      def to_s(io : IO)
        msg = "\n"
        @middlewares.each do |mdware|
          msg += "use #{mdware}\n"
        end
        io << msg
      end
    end
  end
end

# TODO: Implement insert_before, delete, etc.
