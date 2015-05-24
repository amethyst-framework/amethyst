class BaseHandler < HTTP::Handler

  def initialize(@middleware)
  end
    
	def call(base_request : HTTP::Request)
		request = Request.new(base_request)
    @middleware[:request].call
	  response = HTTP::Response.new(200, "Welcome to Amethyst!")                  #TODO create Request and Response classes
   end
 end

    #puts "[Amethyst #{Time.now}] #{request.method} #{request.path}" if verbose  #TODO move to Logger class