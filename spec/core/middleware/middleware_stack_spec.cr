require "../../spec_helper"

mdwstack = MiddlewareStack.new
bsmdware = TestMiddleware.new
request  = Request.new(HTTP::Request.new("GET", "/"))
response = Response.new(200, "OK")

describe MiddlewareStack do

  mdwstack.add(bsmdware)

  it "processes request" do
    mdwstack.process_request(request)
    request.body.should eq "Request is being processed" 
  end

  it "processes response" do
    mdwstack.process_response(request, response)
    response.body.should eq "Response is being processed"
  end
end