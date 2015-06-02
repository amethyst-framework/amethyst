require "./middleware"
require "./logger"

class RequestLogger < Middleware::LoggingMiddleware

  def log_request(request)
    display_object request, "Request" 
    display_subheading "headers"
    display_as_list request.headers, skip = ["Cookie"]
  end

  def log_cookies(headers)
    display_subheading "Cookies", level = 3 
    display_string headers["Cookie"], level = 3
  end

  def log_response(response)
    display_object response, "Response"
  end

  def call(request)
    log_request request
    #log_cookies request.headers
  end

  def call(request, response)
    log_response response
    display_end
  end
end