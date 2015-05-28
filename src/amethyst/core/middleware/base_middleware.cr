class BaseMiddleware
	
	def initialize()
	end

	def call(request : Http::Request)
		request
	end

	def call(request : Http::Request, response : Http::Response)
		response
	end

	def track 
		puts self
	end
end