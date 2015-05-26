require "../../spec_helper"

mdwstack = MiddlewareStack.new
bsmdware = BaseMiddleware.new
request  = Request.new(HTTP::Request.new("GET", "/"))
describe MiddlewareStack do

  it "add method adds middleware" do
    mdwstack.add(bsmdware)
    mdwstack.process_request(request)
  end
end