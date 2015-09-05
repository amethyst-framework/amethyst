require "./middleware"
module Amethyst
  module Middleware
    class TimeLogger < Middleware::Base

      def call(request) : Http::Response
        logger = Base::App.logger
        t_req = Time.now
        response = @app.call(request)
        t_res  = Time.now
        elapsed = (t_res - t_req).to_f*1000
        string  = "%.4f ms" % elapsed
        logger.log_paragraph self
        logger.log_hash({ "Time elapsed" => string })
        response
      end
    end
  end
end
