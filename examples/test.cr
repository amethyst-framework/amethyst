require "../src/amethyst"

class TestController < BaseController

	def index
		html "Hello world!"
  end

  def actions
    add :index
  end
end

Application.configure do |conf|
  conf.environment 7 
end

app = Application.new
app.routes.draw do
  get "/", "test#index"
  register TestController
end

app.serve
