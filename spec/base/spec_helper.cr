require "spec"
require "../../src/all"

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

class TestMiddleware < Base::Middleware

  def call(request, response)
    response.body = "Response is being processed"
  end

  def call(request)
    request.body = "Request is being processed"
  end
end