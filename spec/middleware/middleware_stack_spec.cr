require "./spec_helper"

describe MiddlewareStack do

  describe "#build_middleware" do
    it "builds app" do
      mdwstack = MiddlewareStack.new
      request  = HttpHlp.req("GET", "/")
      mdwstack.use TestMiddleware

      App.settings.configure do |conf|
        conf.environment = "development"
      end
      App.routes.register IndexController
      app = mdwstack.build_middleware
      response = app.call(request)
      response.body.should eq "Request is processed"
    end
  end

  describe "#use" do
    it "adds middleware to stack" do
      mdwstack = MiddlewareStack.new
      request  = HttpHlp.req("GET", "/")
      mdwstack.use TestMiddleware
      
      mdwstack.build_middleware
      mdwstack.includes?(TestMiddleware).should eq true
    end
  end
end
