class MiddlewareStack
  
  def initialize()
    @middleware   = [] of BaseMiddleware
  end

  def process_request(request : Http::Request)
    @middleware.each do |middleware|
      middleware.call(request)
    end
  end

  def process_response(request : Http::Request, response : Http::Response)
    @middleware.reverse.each do |middleware| 
      middleware.call(request, response)
    end
  end

  def add(middleware : Core::BaseMiddleware)
    @middleware << middleware
  end
end