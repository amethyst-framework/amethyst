require "spec"
require "../../src/all"

class IndexController < Base::Controller
  actions :hello, :bye
  def hello
    html "Hello"
  end

  def bye
    html "Bye"
  end
end

class TestMiddleware < Middleware::Base

  def call(request)
    request.body = "Request is being processed"
    @app.call(request)
  end
end

class ViewController < Controller
  actions :index, :hello

  def index
    html "Hello world!<img src='/assets/amethyst.jpg'>"
  end

  view "hello", __DIR__, name
  def hello
    name = "Andrew"
    respond_to do |format|
      format.html { render "hello", name }
    end
  end
end