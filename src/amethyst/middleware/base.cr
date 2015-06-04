# Base middleware class
class Base 
	
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
  
end

class Some < Base 
  
  def call(request)
    puts "new"
    @app.call(request)
  end
end

class Where < Base

  def call(request)
    puts "hello"
    @app.call(request)
  end
end