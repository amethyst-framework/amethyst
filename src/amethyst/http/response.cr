class Response
  property :body
  property :status
  property :headers

  def initialize(@status=nil, @body="" : String, @headers=HTTP::Headers.new, @version="HTTP/1.1")
  end

  def header(key, value)
    @headers[key] = value
  end

  def set(@status, @body)
  end

  # "builds" an HTTP::Response from self
  def build
    return HTTP::Response.new(@status, @body, headers = @headers, version = @version)
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

  def set_cookie(cookie : String)
    headers["Set-Cookie"] = cookie
  end
end