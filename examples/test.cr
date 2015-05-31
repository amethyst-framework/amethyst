require "../src/amethyst"

class TestController < Base::Controller

	def index
		html "Hello world!"
  end

  def actions
    add :index
  end
end


Base::App.settings.configure do |conf| 
  conf.environment 7 
end

app = Base::App.new

app.routes.draw do
  get "/", "test#index"
  register TestController
end


app.serve
