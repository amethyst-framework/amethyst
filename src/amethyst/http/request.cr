class Request
  property :method
  property :path
  property :headers
  property :body
  getter   :version

  # wraps http enviroment 
  def initialize(base_request : HTTP::Request)
    @method  = base_request.method
    @path 	 = base_request.path
    @headers = base_request.headers
    @body 	 = base_request.body
    @version = base_request.version
  end
end

# TODO: Improve Request class, add @env like in Rails