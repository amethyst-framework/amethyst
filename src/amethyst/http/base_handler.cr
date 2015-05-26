class BaseHandler < HTTP::Handler

  def initialize(@middleware_stack)
  end

  def call(base_request : HTTP::Request)
    request  = Request.new(base_request)

    @middleware_stack.process_request(request)
    response = Response.new(200, "Welcome to Amethyst")    # emulates Response returned by controller
    @middleware_stack.process_response(request, response)
    response.build
  end
end