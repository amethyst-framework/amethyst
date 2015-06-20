require "../src/all"

module Say
class TimeLogger < Middleware::Base

  def call(request)
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
  actions :index, :user, :hello, :redirect

  def index
    html "Hello world!<img src='/assets/amethyst.png'>"
  end

  view "hello", "#{__DIR__}/views", name
  def hello
    @name = "Andrew"
    respond_to do |format|
      format.any  { render "hello", @name } 
      format.html { render "hello", @name }
    end
  end

  def user
    html "Hello from user #{request.path_parameters["id"]} \n
    #{Base::App.settings.app_dir}"
  end

  def redirect
    respond_to do |format|
      format.html { redirect_to "user/45" }
    end
  end
  
end

class MyApp < Base::App

  settings.configure do |conf|
    conf.environment = "production"
  end

  routes.draw do
    get  "/user/:id", "test#user"
    post "/post/", "test#index"
    all  "/", "test#hello"
    register TestController
  end

  use TimeLogger
end
end

Say::MyApp.new.serve