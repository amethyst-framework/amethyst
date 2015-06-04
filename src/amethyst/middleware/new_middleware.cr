class New 
	
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