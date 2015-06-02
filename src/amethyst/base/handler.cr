class Handler

  def initialize(@router)
  end

  def call(base_request : HTTP::Request)
    request  = Http::Request.new(base_request)
    Middleware::MiddlewareStack::INSTANCE.process_request(request)
    response = @router.call(request)
    Middleware::MiddlewareStack::INSTANCE.process_response(request,response)
    response.build
  end
end