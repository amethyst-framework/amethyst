require "./spec_helper"

describe Response do
  
  response = Response.new(404, "Not Found")

  it "set's header" do
    response.header("Content-Type", "text/html")
    response.headers.length.should eq 1
    response.headers["Content-Type"].should eq "text/html"
  end

  it "should build HTTP::Response" do
    response.build.should be_a HTTP::Response
  end
end
