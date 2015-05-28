class Response
  property body
  property status_code
  setter headers
  getter headers
  #TODO add cookies

  def initialize(@status_code=nil, @body=nil,@headers=HTTP::Headers.new, @version="HTTP/1.1")
  end

  # "builds" an HTTP::Response from self
  def build
    return HTTP::Response.new(@status_code, @body, headers = @headers, version = @version)
  end
end