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