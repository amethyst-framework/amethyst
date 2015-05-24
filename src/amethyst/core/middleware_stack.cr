struct MiddlewareStack
  getter request_middlewares
  getter response_middlewares
  
  def initialize()
    @request_middlewares   = [] of Middleware
    @response_middlewares  = [] of Middleware
  end

  def add(middleware : Middleware)
    @request_middlewares << middleware
  end
end