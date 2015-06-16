require "spec"
require "../src/all"

require "minitest/autorun"

class IndexController < Base::Controller
  actions :hello, :bye
  def hello
    html "Hello"
  end

  def bye
    html "Bye"
  end
end

class MatchedController < Base::Controller
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
    response = HTTP::Response.new(200, "Ok")
    @app.call(request)
  end
end