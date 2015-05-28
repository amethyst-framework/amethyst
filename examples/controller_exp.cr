require "../src/all"

class IndexController < BaseController
	def hello(request)
		puts "hello"
	    Response.new(200, "Hello!Welcome to Amethyst")    # emulates Response returned by controller
	end

	def actions
		add :hello
	end
end

app = Application.new
app.routes.draw do |routes|
	get "/index", "index#hello"
	#p app.routes
end
app.routes.register(IndexController)
app.serve