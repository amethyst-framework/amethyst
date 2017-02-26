module Amethyst
  module Middleware
    class MiddlewareStack

      include Sugar::Klass
      singleton_INSTANCE
      include Enumerable(Class)

      def initialize()
        @middlewares   = [] of Middleware::Base.class
      end

      def build_middleware
        app = Dispatch::Router.instance
        @middlewares.reverse.each do |mdware|
          mdware = instantiate mdware
          app = mdware.build(app)
        end
        puts self if Amethyst::Base::App.settings.environment == "development"
        app
      end

      def use(middleware)
        @middlewares << middleware
      end

      def each
        0.upto(@middlewares.length-1) do |i|
          yield @middlewares[i]
        end
      end

      def includes?(middleware)
        @middlewares.includes? middleware
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
