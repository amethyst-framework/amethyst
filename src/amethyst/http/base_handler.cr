class BaseHandler < HTTP::Handler

  def initialize(@middleware_stack)
  end

  def call(base_request : HTTP::Request)
    request  = Request.new(base_request)
    response = Response.new
    @middleware_stack.request_middleware.each do |middleware|
       middleware.call(request, response)
    end
    response.build
  end
end