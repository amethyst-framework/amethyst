class MiddlewareStack

  include Sugar
  singleton_INSTANCE
  
  def initialize()
    @middleware   = [] of Middleware::Base
  end

  # This method is invoked when the application receives a request
  # Invokes call(Http::Request) of each middleware
  def process_request(request : Http::Request)
    @middleware.each do |middleware|
      middleware.call request
    end
  end

  # This method is invoked when the application handler returns a response
  # Invokes call(Http::Request, Http::Response) of each middleware in reverse order
  def process_response(request : Http::Request, response : Http::Response)
    @middleware.reverse.each do |middleware| 
      middleware.call request, response
    end
  end

  # Adds middleware instance to the @middleware array
  def add(middleware : Middleware::Base.class)
    @middleware << instantiate middleware
  end
end