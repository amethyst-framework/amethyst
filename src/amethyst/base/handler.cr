class Handler
  
	# def call(base_request : HTTP::Request)
	# 	request  = Http::Request.new(base_request)
	# 	Middleware::MiddlewareStack::INSTANCE.process_request(request)
	# 	response = Dispatch::Router::INSTANCE.call(request)
	# 	Middleware::MiddlewareStack::INSTANCE.process_response(request,response)
	# 	response.build
	# end

  def call(base_request : HTTP::Request)
    request  = Http::Request.new(base_request)
    app = Middleware::MiddlewareStack::INSTANCE.build
    response = app.call(request)
    response.build
  end
end