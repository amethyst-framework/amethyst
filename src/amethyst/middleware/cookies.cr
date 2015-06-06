require "cgi"
class Cookies < Middleware::Base

  def parse_cookies(cookies_string)
    cookies_hash = {} of String => String
    cookies = cookies_string.split(";")
    cookies.each do |cookie|
      key, value = cookie.split("=")
      key   = CGI.unescape(key)
      value = CGI.unescape(value)
      cookies_hash[key.strip] = value.strip
    end
    cookies_hash
  end

  def call(request)
    unless request.headers.has_key? "Cookie"
      response = @app.call(request)
    else
      request.cookies = parse_cookies(request.headers["Cookie"])
      puts request.cookies
      response = @app.call(request)
    end
    response
  end
end

