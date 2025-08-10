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
        @middleware_instances = nil
      end
      
      # Insert middleware before another middleware
      def insert_before(target : Middleware::Base.class, middleware : Middleware::Base.class)
        index = @middlewares.index(target)
        if index
          @middlewares.insert(index, middleware)
        else
          # If target not found, add at the beginning
          @middlewares.unshift(middleware)
        end
      end
      
      # Insert middleware after another middleware
      def insert_after(target : Middleware::Base.class, middleware : Middleware::Base.class)
        index = @middlewares.index(target)
        if index
          @middlewares.insert(index + 1, middleware)
        else
          # If target not found, add at the end
          @middlewares << middleware
        end
      end
      
      # Delete middleware from the stack
      def delete(middleware : Middleware::Base.class)
        @middlewares.delete(middleware)
        # Also remove from instances if it exists
        if instances = @middleware_instances
          instances.delete(middleware.name)
        end
      end
      
      # Replace middleware with another
      def replace(target : Middleware::Base.class, replacement : Middleware::Base.class)
        index = @middlewares.index(target)
        if index
          @middlewares[index] = replacement
          # Remove old instance
          if instances = @middleware_instances
            instances.delete(target.name)
          end
        else
          # If target not found, just add the replacement
          @middlewares << replacement
        end
      end
      
      # Check if middleware exists in the stack
      def has?(middleware : Middleware::Base.class) : Bool
        @middlewares.includes?(middleware)
      end
      
      # Get the current middleware stack order
      def stack : Array(Middleware::Base.class)
        @middlewares.dup
      end
      
      # Get the size of the middleware stack
      def size : Int32
        @middlewares.size
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

# Middleware stack functionality: insert_before, delete, replace, etc. - IMPLEMENTED
