# Base middleware class
abstract class Base
	
	def initialize()
    @app = self
	end

	def call(request : Http::Request)
	end

  def build(app)
    @app = app
    self
  end

	def call(request : Http::Request, response : Http::Response)
	end
end