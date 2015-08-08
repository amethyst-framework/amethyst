require "./spec_helper"

describe Response do

  response = Response.new(404, "Not Found")

  describe "#header" do
    it "sets header" do
      response.header "Content-Type", "text/html"
      response.headers.length.should eq 1
      response.headers["Content-Type"].should eq "text/html"
    end
  end

  describe "#build" do
    it "should return HTTP::Response" do
      response.build.should be_a HTTP::Response
    end
  end

  describe "#cookie" do
    it "should add a proper simple cookies to 'Set-Cookie' header" do
      response = HttpHlp.res(200, "Ok")
      response.cookie "id", 22
      response.cookie "name", "Amethyst"
      response.headers["Set-Cookie"].should eq "id=22,name=Amethyst"
    end

    it "should add a proper complex cookie to 'Set-Cookie' header" do
      response = HttpHlp.res(200, "Ok")
      response.cookie "id", 22, http_only: true, secure: true, path: "/", domain: "test.com"
      response.headers["Set-Cookie"].should eq "id=22; domain=test.com; path=/; secure; HttpOnly"
    end
  end
end
