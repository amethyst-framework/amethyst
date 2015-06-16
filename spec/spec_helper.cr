require "spec"
require "../src/all"

#require "minitest/autorun"
#require "webmock"

class TestMiddleware < Middleware::Base

  def call(request)
    request.body = "Request is being processed"
    response = HTTP::Response.new(200, "Ok")
    @app.call(request)
  end
end

def create_controller_instance(controller : Base::Controller.class) 
  headers      = HTTP::Headers.new
  base_request = HTTP::Request.new("GET", "/", headers, "Test")
  request      = Http::Request.new(base_request)
  response     = Http::Response.new(404, "Not Found")
  controller = IndexController.new
  controller.set_env(request, response)
  controller
end