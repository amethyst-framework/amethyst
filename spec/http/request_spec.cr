require "./spec_helper"

describe Request do

  headers           = HTTP::Headers.new
  headers["Accept"] = ["text/plain"]
  base_request      = HTTP::Request.new("GET", "/", headers, "Test")
  req               = Request.new(base_request)

  it "instantiates properly" do
    req.method.should             eq "GET"
    req.path.should               eq "/"
    req.headers["Accept"].should  eq "text/plain"
    req.body.should               eq "Test"
    req.version.should            eq "HTTP/1.1"
  end

  it "checks http methods" do
    base_request = HTTP::Request.new("GET", "/", headers, "Test")
    req          = Request.new(base_request)
    req.get?.should eq true

    base_request = HTTP::Request.new("POST", "/", headers, "Test")
    req          = Request.new(base_request)
    req.post?.should eq true

    base_request = HTTP::Request.new("PUT", "/", headers, "Test")
    req          = Request.new(base_request)
    req.put?.should eq true

    base_request = HTTP::Request.new("DELETE", "/", headers, "Test")
    req          = Request.new(base_request)
    req.delete?.should eq true

    base_request = HTTP::Request.new("PUT", "/", headers, "Test")
    req          = Request.new(base_request)
    req.get?.should eq false
  end

  it "returns query string, if exists" do
    q_base_request = HTTP::Request.new("GET", "/index/path.html?p1=v1&p2=v2", headers, "Test")
    q_req          = Request.new(q_base_request)
    q_req.query_string.should eq "p1=v1&p2=v2"
    q_req.path = "/index/"
    q_req.query_string.should eq nil
  end

  it "returns path without query string" do
    path_request = HTTP::Request.new("GET", "/index", headers, "Test")
    path_req     = Request.new(path_request)
    path_req.path.should eq "/index"
    path_request = HTTP::Request.new("GET", "/index?user_id=1", headers, "Test")
    path_req     = Request.new(path_request)
    path_req.path.should eq "/index"
  end

  it "returns query parameters" do
    qp_request = HTTP::Request.new("GET", "/index?user=user&name=name", headers, "Test")
    qp_req = Request.new(qp_request)
    qp_req.query_parameters.should eq Hash{"user" : "user", "name" : "name"}
  end

  it "returns query (GET) parameters" do
    base_request = HTTP::Request.new("GET", "/index?user=Andrew&id=5", headers, "Test")
    request      = Request.new(base_request)
    request.query_parameters.should eq Hash{ "user" => "Andrew", "id" => "5"}
  end

  it "returns request (POST) parameters" do
    base_request = HTTP::Request.new("GET", "/", headers, "Test")
    request      = Request.new(base_request)
    request.body = "user=Andrew&id=5"
    p request.body
    request.content_type = "application/x-www-form-urlencoded"
    request.request_parameters.should eq Hash{ "user" => "Andrew", "id" => "5"}
  end
end
