class TimeMiddleware < Middleware::LoggingMiddleware

  # All instance variables have to be initialized here to use them in call methods
  def initialize
    super
    @t_req = Time.new 
    @t_res = Time.new
  end

  # This one will be called when app gets request. It accepts Http::Request
  def call(request)
    @t_req = Time.now
  end

  # This one will be called when response returned from controller. It accepts both
  # Http::Request and Http::Response
	def call(request, response)
    @t_res  = Time.now
    elapsed = (@t_res - @t_req).to_f*1000
    display_name
    display_string "Time elapsed:  %.4f ms" % elapsed
  end

end