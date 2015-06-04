class New 
	
	def initialize()
    @app = self
	end

	def call(request : Http::Request)
    @app.call(request)
	end

  def build(app)
	  @app = app
	  self
	end
  
	# def call(request : Http::Request, response : Http::Response)
	# end
end

class Some < New 
  
  def call(request : Http::Request)
    puts "self"
    @app.call(request)
  end
end