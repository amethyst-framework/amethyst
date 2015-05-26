class BaseMiddleware
	
	def initialize()
	end

	def call(request : Request)
		request
	end

	def call(request : Request, response : Response)
		response
	end
end