require "../../spec_helper"

mdwstack = MiddlewareStack.new
bsmdware = BaseMiddleware.new

describe MiddlewareStack do

  it "instantiates properly" do
    mdwstack.request_middleware.should  be_a   Array(BaseMiddleware)
    mdwstack.response_middleware.should be_a  Array(BaseMiddleware)
  end

  it "add method adds middleware" do
    mdwstack.add(bsmdware)
    mdwstack.request_middleware.length.should eq 1
  end
end