require "../src/all"

class IndexController
	def hello
	end
end

app = Application.new
app.routes.draw do |routes|
	get "/index", "index#new"
end
app.routes.register(IndexController)
app.serve