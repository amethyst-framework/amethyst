class BaseMiddleware

  def call(request : Request, response : Response)
  	HTTP::Response.new(200, "#{self}")
  end
end