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
  	it "should add a 'Set-" do
  	end
  end
end
