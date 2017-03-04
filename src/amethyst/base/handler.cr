module Amethyst
  module Base
    class Handler
      include HTTP::Handler

      @app : Dispatch::Router|Middleware::Base

      def initialize(app)
        @app = app
      end

      def call(context : HTTP::Server::Context)
        request  = Http::Request.new(context.request)
        response = @app.call(request)
        response.build context.response

        context
      end
    end
  end
end
