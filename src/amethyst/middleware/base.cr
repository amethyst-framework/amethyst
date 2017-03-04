# Base middleware class
module Amethyst
  module Middleware
    abstract class Base
      @app : Middleware::Base | Dispatch::Router

      def initialize(@app = self)
      end

      def call(request : Http::Request) : Http::Response
        @app.call(request)
      end

      def build(app)
       @app = app
       self
      end
    end
  end
end
