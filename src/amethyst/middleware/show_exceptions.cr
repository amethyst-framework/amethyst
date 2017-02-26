module Amethyst
  module Middleware
    class ShowExceptions < Middleware::Base
      def initialize(@app = self)
      end

      def call(request : Http::Request)
        begin
          response = @app.call(request)
        rescue httpexception : Exceptions::HttpException
          Http::Response.new(httpexception.status, httpexception.msg)
        rescue ex : Exception
          if Amethyst::Base::App.settings.environment == "development"
            response = Http::Response.new(200, "ERROR: #{ex.message}\n\n#{ex.backtrace.join '\n'}\n")
          else
            response = Http::Response.new(404, "404 Not Found")
          end
        ensure
          response
        end
      end
    end
  end
end

#TODO : Make an exception controller and view
