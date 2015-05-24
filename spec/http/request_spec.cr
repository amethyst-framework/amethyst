require "../spec_helper"

headers = HTTP::Headers.new
headers["Accept"] = ["text/plain"]
base_request = HTTP::Request.new("GET", "/", headers, "Test")
req = Request.new(base_request)

describe Request do

  it "instantiates properly" do
    req.method.should             eq "GET"
    req.path.should               eq "/"
    req.headers["Accept"].should  eq "text/plain"
    req.body.should               eq "Test"
    req.version.should            eq "HTTP/1.1"
  end
end
