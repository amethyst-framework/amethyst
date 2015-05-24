require "../spec_helper"

request = HTTP::Request.new("GET", "/")
mdwstck = MiddlewareStack.new
handler = BaseHandler.new(mdwstck)

describe BaseHandler do

  it "instantiates properly" do
  end

  it "call method return Response object" do
    response = handler.call(request)
    response.should be_a HTTP::Response
  end
end
