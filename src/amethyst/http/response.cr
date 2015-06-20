class Response
  property :body
  property :status
  property :headers
  property :cookies

  include Support::HeaderHelper

  def initialize(@status=nil, @body="" : String, @headers=HTTP::Headers.new, @version="HTTP/1.1")
  end

  def set(@status, @body)
  end

  # "builds" an HTTP::Response from self
  def build
    return HTTP::Response.new(@status, @body, headers = @headers, version = @version)
  end

  def cookie(key, value, secure=false, http_only=false, path="", domain="")
    cookie_string = "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
    cookie_string += "; domain=#{domain}" unless domain.empty?
    cookie_string += "; path=#{path}" unless path.empty?
    cookie_string += "; secure"  if secure
    cookie_string += "; HttpOnly" if http_only
    headers.add "Set-Cookie", cookie_string
  end

  def log
    if headers.has_key?("Content-type") && (headers["Content-type"] == ("text/html"||"text/plain"))
      body = @body
    else 
      body = ""
    end
    {
      "status"   :  status,
      "response" :  body,
      "version"  :  @version
    }
  end
end