require "spec"
#require "minitest/autorun"
#require "webmock"

require "../src/all"

class IndexController < BaseController
  def hello
    HTTP::Response.new(200, "Hello")
  end

  def bye
    HTTP::Response.new(200, "Bye")
  end

  def actions
    add :hello
    add :bye
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