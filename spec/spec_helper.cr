require "spec"
#require "minitest/autorun"
#require "webmock"

require "../src/all"

class IndexController < BaseController

  def hello(request)
    HTTP::Response.new(200, "Hello")
  end

  def actions
    add :hello
  end
end

class TestMiddleware < BaseMiddleware

  def call(request, response)
    response.body = "Response is being processed"
  end

  def call(request)
    request.body = "Request is being processed"
  end
end