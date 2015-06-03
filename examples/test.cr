require "../src/all"

class TestController < Controller

	def index
		html "Hello world!"
  end

  def actions
    add :index
  end
end


App.settings.configure do |conf|
  conf.environment "development" 
end

app = App.new

app.routes.draw do
  get "/", "test#index"
  register TestController
end


app.serve
