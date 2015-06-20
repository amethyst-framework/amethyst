require "../src/all"

class TestController < Controller
  actions :index, :user

  def index
    html "Hello world!<img src='/examples/assets/amethyst.png'>  #{Base::App.settings.app_dir}"

    response.cookie "session", "Amethyst"
    response.cookie "name", "Andrew"
  end

  def user
    text "Here are users live :)"
  end
end

App.settings.configure do |conf|
  conf.environment = "production"
  conf.static_dirs = [ "/examples/assets"]
end

App.routes.draw do
  get  "/user/:id", "test#user"
  post "/post/", "test#index"
  all  "/", "test#index"
  register TestController
end

App.use TimeLogger

app = App.new

app.serve
