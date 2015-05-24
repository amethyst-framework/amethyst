require "../src/all"

class HelloMiddleware < BaseMiddleware

  def initialize(@msg)
  end

	def call(request, response)
    response.body = "Hello, #{@msg} \n Request headers is #{request.headers}"
  end
end

app = Application.new
app.use(HelloMiddleware.new("Amethyst"))
app.serve
