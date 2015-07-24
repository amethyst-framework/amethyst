require "./spec_helper"

describe HeaderHelper do

  base_request = HTTP::Request.new("GET", "/")
  request      = Http::Request.new(base_request)
  response     = Http::Response.new(200, "OK")

  it "sets and returns headers" do
    request.header "Accept", "text/html"
    response.header "Location", "google.com"

    request.header("Accept").should eq "text/html"
    response.header("Location").should eq "google.com"
  end

  it "determines if header exists" do
    request.header "Accept", "text/html"
    response.header "Location", "google.com"

    request.has_header?("Accept").should eq true
    request.has_header?("Header").should eq false
    response.has_header?("Location").should eq true
    response.has_header?("Header").should eq false
  end

  it "sets and returns Content-type header" do
    request.content_type.should eq ""
    response.content_type.should eq ""

    request.content_type = "application/x-www-form-urlencoded"
    response.content_type = "plain/text"
    request.content_type.should eq "application/x-www-form-urlencoded"
    response.content_type.should eq "plain/text"
  end

  it "sets Content-type header from file extension" do
    request.ctype_ext = "html"
    request.content_type.should eq "text/html"
  end

  it "returns an exception if content type for file doesn't exists" do
    expect_raises Exceptions::UnknownContentType do
      request.ctype_ext = "htmlas"
    end
  end
end
