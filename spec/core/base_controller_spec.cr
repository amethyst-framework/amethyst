require "../spec_helper"

class IndexController < BaseController
  def hello(request)
    HTTP::Response.new(200, "Hello")
  end

  def bye(request)
    HTTP::Response.new(200, "Bye")
  end

  def actions
    add :hello
    add :bye
  end
end

controller = IndexController.new

describe IndexController do

  it "instantiates properly" do
    controller.actions_hash.should be_a Hash
    controller.actions_hash.length.should eq 2
  end

  it "actions method captures actions properly" do
    controller.actions_hash["hello"].should eq ->controller.hello(String)
    controller.actions_hash["bye"].should be_a Proc
  end

  it "actions return HTTP::Response" do
    response = controller.call_action("bye", "request")
    response.should be_a HTTP::Response
    response.status_code.should eq 200
    response.body.should eq "Bye"
  end
end