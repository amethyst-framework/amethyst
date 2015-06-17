require "../src/all"

class TestController < Controller
  actions :index, :user

  def index
    html "Hello world!<img src='/assets/amethyst.jpg'>"
  end

  def user
    text "Here are users live :)"
  end
end

class TestMiddleware < Middleware::Base

  def call(request) : Http::Response
    request.body = "Request is being processed"
    response = HTTP::Response.new(200, "Ok")
    @app.call(request)
  end
end

App.settings.configure do |conf|
  conf.environment = "production"
end

App.use TestMiddleware

App.routes.draw do
  get  "/user/:id", "test#user"
  post "/post/", "test#index"
  all  "/", "test#index"
  register TestController
end

app = App.new

app.serve
