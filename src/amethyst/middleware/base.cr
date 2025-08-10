# Base middleware class
module Amethyst
  module Middleware
    abstract class Base
      @app : (Middleware::Base | Routing::OptimizedRouter)?

      def initialize(@app : Middleware::Base | Routing::OptimizedRouter? = nil)
        @app = @app || self.as(Middleware::Base | Routing::OptimizedRouter)
      end

      def call(request : Http::Request) : Http::Response
        if app = @app
          app.call(request)
        else
          Http::Response.new(500, "Internal Server Error")
        end
      end

      def build(app)
       @app = app
       self
      end
    end
  end
end
