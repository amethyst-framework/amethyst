class BaseHandler < HTTP::Handler

  def initialize(@middleware_stack, @router)
    p self
  end

  def call(base_request : HTTP::Request)
    request  = Request.new(base_request)
    #@middleware_stack.process_request(request)
    response = @router.call(request)
    #@middleware_stack.process_response(request,response)
    unless response
      HTTP::Response.new(404, "Not Found")
    else response
    end
  end
end