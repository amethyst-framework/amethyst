require "../src/all"

class TestController < Controller
  actions :index

	def index
		html "Hello world!<img src='/assets/amethyst.jpg'>"
  end

  def user
    html "Here are users live :)"
  end

end


App.settings.configure do |conf|
  conf.environment = "development"
end

App.routes.draw do
  get  "/user/:id", "test#user"
  post "/post/", "test#index"
  all  "/", "test#index"
  register TestController
end

app = App.new

app.serve