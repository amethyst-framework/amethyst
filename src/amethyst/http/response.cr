class Response
  property :body
  property :headers
  property :cookies
  getter   :status

  include Support::HeaderHelper

  def initialize(@status=nil, @body="" : String, @headers=HTTP::Headers.new, @version="HTTP/1.1")
  end

  def set(@status, @body)
  end

  def status=(status : Int32)
    @status = status
  end

  # "builds" an HTTP::Response from self
  def build
    return HTTP::Response.new(@status, @body, headers = @headers, version = @version)
  end

  def cookie(key, value, secure=false, http_only=false, path="", domain="", expires="")
    cookie_string = String.build do |string|
      string << "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
      string << "; domain=#{domain}" unless domain.to_s.empty?
      string << "; path=#{path}" unless path.to_s.empty?
      string << "; secure"  if secure
      string << "; HttpOnly" if http_only
      string << "; Expires=#{expires}" unless expires.to_s.empty?
    end
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