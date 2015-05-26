require "../src/all"
require "time"

class TimeMiddleware < BaseMiddleware

  def initialize
    @t_req = Time.new 
    @t_res = Time.new
  end

  def call(request, env)
    @t_req = Time.now
  end

	def call(request, response, env)
    @t_res = Time.now
    response.body = "Time elapsed: #{(@t_req-@t_res)}"
  end

end

app = Application.new
app.use(TimeMiddleware.new)
app.serve
