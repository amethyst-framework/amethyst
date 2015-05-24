class Response
  property headers
  property body
  property status

  # wraps http enviroment 
  def initialize(@status = nil, @body= nil)
  end

  def build
    HTTP::Response.new(@status, @body)
  end
end