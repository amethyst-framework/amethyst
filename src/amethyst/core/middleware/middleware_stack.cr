struct MiddlewareStack
  getter request_middleware
  getter response_middleware
  
  def initialize()
    @request_middleware   = [] of BaseMiddleware
    @response_middleware  = [] of BaseMiddleware
  end

  def add(middleware : BaseMiddleware)
    @request_middleware << middleware
  end
end