require "../../spec_helper"

request  = Request.new(HTTP::Request.new("GET", "/"))
response = Response.new(200, "OK")
bsmware  = BaseMiddleware.new

describe BaseMiddleware do

  it "instantiates properly" do
    bsmware.should be_a BaseMiddleware
  end

  it "works" do
  	bsmware.call(request, response).should be_a HTTP::Response
  end
end