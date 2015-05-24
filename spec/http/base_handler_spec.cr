require "../spec_helper"

handler = BaseHandler.new
request = HTTP::Request.new("GET", "/")

describe BaseHandler do
  it "call method return Response object" do
    response = handler.call(request, false)
    response.should be_a HTTP::Response
  end
end
