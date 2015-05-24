struct MiddlewareStack
  getter request_middlewares
  getter response_middlewares
  
  def initialize()
    @request_middlewares   = [] of BaseMiddleware
    @response_middlewares  = [] of BaseMiddleware
  end

  def add(middleware : BaseMiddleware)
    @request_middlewares << middleware
  end
end