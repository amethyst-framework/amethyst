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

  it "checks http methods" do
     base_request = HTTP::Request.new("GET", "/", headers, "Test")
     req = Request.new(base_request)
     req.get?.should eq true

     base_request = HTTP::Request.new("POST", "/", headers, "Test")
     req = Request.new(base_request)
     req.post?.should eq true

     base_request = HTTP::Request.new("PUT", "/", headers, "Test")
     req = Request.new(base_request)
     req.put?.should eq true

     base_request = HTTP::Request.new("DELETE", "/", headers, "Test")
     req = Request.new(base_request)
     req.delete?.should eq true

     base_request = HTTP::Request.new("PUT", "/", headers, "Test")
     req = Request.new(base_request)
     req.get?.should eq false
  end
end
