require "../spec_helper"

headers = HTTP::Headers.new
headers["Accept"] = ["text/plain"]
base_request = HTTP::Request.new("GET", "/", headers, "Test")
request = Request.new(base_request)
controller = IndexController.new(request)

describe IndexController do

  it "instantiates properly" do
    controller.actions_hash.should be_a Hash
    controller.actions_hash.length.should eq 2
  end

  it "actions method captures actions properly" do
    controller.actions_hash["hello"].should eq ->controller.hello
    controller.actions_hash["bye"].should be_a Proc
  end

  it "actions return HTTP::Response" do
    response = controller.call_action("bye")
    response.should be_a HTTP::Response
    response.status_code.should eq 200
    response.body.should eq "Bye"
  end
end