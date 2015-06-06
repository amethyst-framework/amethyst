require "./middleware"
class HttpLogger < Middleware::Base
  getter :logger

  def initialize
    super()
    @logger = Base::App.logger
  end

  def log_request(request)
    logger.indent = 3
    logger.display_object request, "Request" 
    logger.indent = 6
    logger.display_subheading "headers"
    logger.display_as_list request.headers, skip = ["Cookie"]
  end

  def log_cookies(headers)
    logger.display_subheading "Cookies", level = 3
    if headers["Cookie"]
      logger.display_string headers["Cookie"], level = 3
    end
  end

  def log_response(response)
    logger.indent = 3
    logger.display_object response, "Response"
  end

  def call(request)
    # system("clear")
    logger.display_name
    log_request request
    log_cookies(request.headers)
    response = @app.call(request)
    logger.display_name
    log_response response
    logger.indent = 6
    logger.display_subheading "headers"
    logger.display_as_list response.headers
    puts "\n\n"
    response
  end
end