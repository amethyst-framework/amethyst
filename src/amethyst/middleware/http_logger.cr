require "./middleware"

module Amethyst
  module Middleware
    class HttpLogger < Middleware::Base
      @logger : Amethyst::Base::Logger

      getter :logger

      def initialize(@app = self)
        @logger = Amethyst::Base::App.logger
      end

      def log_request(request)
        logger.indent = 3
        logger.log_object request, "Request"
        logger.indent = 6
        logger.log_subheading "headers"
        logger.log_hash request.headers, skip = ["Cookie"]
      end

      def log_cookies(headers)
        logger.log_subheading "Cookies", level = 3
        if headers["Cookie"]?
          logger.log_string headers["Cookie"], level = 3
        end
      end

      def log_session(request)
        logger.log_subheading "Session", level = 3
        logger.indent = 3
        session_id = request.cookies["sid"]
        logger.log_string Amethyst::Base::App.session.get_session(session_id).to_s, level = 3
      end

      def log_response(response)
        logger.indent = 3
        logger.log_object response, "Response"
      end

      def call(request)
        #system("clear")
        logger.log_paragraph self
        log_request request
        log_cookies(request.headers)
        log_session request
        response = @app.call(request)
        logger.log_paragraph self
        log_response response
        logger.indent = 6
        logger.log_subheading "headers"
        logger.log_hash response.headers
        logger.log_end
        response
      end
    end
  end
end
