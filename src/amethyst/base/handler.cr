class Handler
  
  def call(base_request : HTTP::Request)
    request  = Http::Request.new(base_request)
    app = Middleware::MiddlewareStack::INSTANCE.build_middleware
    response = app.call(request)
    response.build
  end
end