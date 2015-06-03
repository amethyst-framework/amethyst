require "./middleware"
require "./logging_middleware"

class HttpLogger < Middleware::LoggingMiddleware

  def log_request(request)
    @indent = 3
    display_object request, "Request" 
    @indent = 6
    display_subheading "headers"
    display_as_list request.headers, skip = ["Cookie"]
  end

  def log_cookies(headers)
    display_subheading "Cookies", level = 3 
    display_string headers["Cookie"], level = 3
  end

  def log_response(response)
    @indent = 3
    display_object response, "Response"
  end

  def call(request)
    system("clear")
    display_name
    log_request request
    #log_cookies request.headers
  end

  def call(request, response)
    display_name
    log_response response
    @indent = 6
    display_subheading "headers"
    display_as_list response.headers
  end
end