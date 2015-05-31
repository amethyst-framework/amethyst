class Handler

  def initialize(@middleware_stack, @router)
  end

  def call(base_request : HTTP::Request)
    request  = Http::Request.new(base_request)
    @middleware_stack.process_request(request)
    response = @router.call(request)
    @middleware_stack.process_response(request,response)
    response.build
  end
end