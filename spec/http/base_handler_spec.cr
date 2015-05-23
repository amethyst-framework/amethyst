require "../spec_helper"
include Amethyst::Http

handler = BaseHandler.new
request = HTTP::Request.new("GET", "/")

describe BaseHandler do
  it "call method return Response object" do
    response = handler.call(request)
    response.should be_a HTTP::Response
  end
end
