class Response
  property body
  property status

  def initialize(@status = nil, @body= nil)
  end

  # "builds" an HTTP::Response from self
  def build
    HTTP::Response.new(@status, @body)
  end
end