require "spec"
require "../src/all"

#require "minitest/autorun"
#require "webmock"

class IndexController < Base::Controller
  actions :hello, :bye, :hello_you
  def hello
    html "Hello"
  end

  def hello_you
    html "Hello, you!"
  end

  def bye
    html "Bye"
  end
end

class TestMiddleware < Middleware::Base

  def call(request) : Http::Response
    response = @app.call(request)
    response.body = "Request is processed"
    response
  end
end

def create_controller_instance(controller : Base::Controller.class)
  request, response = HttpHlp.get_env
  controller = controller.new
  controller.set_env(request, response)
  controller
end

class HttpHlp
  property :req
  property :res

  def initialize
    @req  = self.class.req("GET", "/")
    @res = self.class.res(200, "OK")
  end

  def self.get_env
    instance = new
    return instance.req, instance.res
  end

  def get_env
    return req, res
  end

  def self.req(method, path)
    headers      = HTTP::Headers.new
    base_request = HTTP::Request.new(method, path, headers, "Test")
    request      = Http::Request.new(base_request)
    request
  end

  def self.res(code, body)
    response     = Http::Response.new(code, body)
    response
  end
end
