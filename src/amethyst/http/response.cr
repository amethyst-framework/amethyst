class Response
  property headers
  property body

  # wraps http enviroment 
  def initialize
    @body = nil
  end

  def build
    HTTP::Response.new(200, @body)
  end
end