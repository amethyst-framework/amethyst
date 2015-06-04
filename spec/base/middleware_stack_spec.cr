require "./spec_helper"

describe MiddlewareStack do
  
	mdwstack = MiddlewareStack.new
	request  = Request.new(HTTP::Request.new("GET", "/"))
	mdwstack.use TestMiddleware

  it "processes request" do
    # App.settings.configure do |conf|
    #   conf.environment "production"
    # end
    # app = mdwstack.build_middleware
    # app.call(request)
    # request.body.should eq "Request is being processed"
    # ???strange errors???
  end
end