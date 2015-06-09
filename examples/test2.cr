require "../src/all"

class TimeLogger < Middleware::Base

  # This one will be called when app gets request. It accepts Http::Request
  def call(request)
    logger   = Base::App.logger
    t_req    = Time.now
    response = @app.call(request)
    t_res    = Time.now
    elapsed  = (t_res - t_req).to_f*1000
    string   = "%.4f ms" % elapsed
    response.body += "<hr>"+string
    response
  end
end

class TestController < Controller
  actions :index

  def index
    html "Hello world!<img src='/assets/amethyst.jpg'>"
  end

  def user
    text "Here are users live :)"
  end
end

class MyApp < Base::App

  settings.configure do |conf|
    conf.environment = "production"
  end

  routes.draw do
    get  "/user/:id", "test#user"
    post "/post/", "test#index"
    all  "/", "test#index"
    register TestController
  end

  use TimeLogger
end

MyApp.new.serve