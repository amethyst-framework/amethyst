class BaseHandler < HTTP::Handler

  def initialize(@middleware_stack, @router)
  end

  def call(base_request : HTTP::Request)
    request  = Request.new(base_request)
    #@middleware_stack.process_request(request)
    response = @router.call(request)
    #@middleware_stack.process_response(request,response)
    #return response.build
    #response = Http::Response.new(200, "OK")
    response.build
    #HTTP::Response.new(200, "OK")
  end
end