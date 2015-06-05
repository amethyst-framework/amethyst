require "../src/all"

class TestController < Controller
  actions :index

	def index
    puts @actions_hash
		html "Hello world!"
  end

  # def actions
  #   add :index
  # end
end


App.settings.configure do |conf|
  conf.environment "development" 
end

App.routes.draw do
  get  "/user/:id", "test#index"
  post "/post/", "test#index"
  register TestController
end

app = App.new

app.serve
