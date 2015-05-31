require "./spec_helper"

describe Request do

  headers = HTTP::Headers.new
  headers["Accept"] = ["text/plain"]
  base_request = HTTP::Request.new("GET", "/", headers, "Test")
  req = Request.new(base_request)

  it "instantiates properly" do
    req.method.should             eq "GET"
    req.path.should               eq "/"
    req.headers["Accept"].should  eq "text/plain"
    req.body.should               eq "Test"
    req.version.should            eq "HTTP/1.1"
  end
end
