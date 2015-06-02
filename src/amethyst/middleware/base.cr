# Base middleware class
abstract class Base
	
	def initialize()
	end

	def call(request : Http::Request)
	end

	def call(request : Http::Request, response : Http::Response)
	end
end