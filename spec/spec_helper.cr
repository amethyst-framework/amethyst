require "spec"
require "../src/all"

#require "minitest/autorun"
#require "webmock"


class IndexController < Base::Controller
  def hello
    html "Hello"
  end

  def bye
    html "Bye"
  end

  def actions
    add :hello
    add :bye
  end
end

class TestMiddleware < Middleware::Base

  def call(request)
    request.body = "Request is being processed"
    response = HTTP::Response.new(200, "Ok")
    # @app.call(request)
  end
end