require "./spec_helper"

describe Router do

  router     = Router.new
  request    = Http::Request.new(HTTP::Request.new("GET", "/index"))
  response   = Http::Response.new(200, "Ok")
  controller = IndexController.new
  controller.set_env(request, response)

  it "draws routes properly" do
    router.draw do
      get "/index/", "index#hello"
    end
    router.routes[0].should be_a Amethyst::Dispatch::Route
  end

  it "registers controller" do
    router.register(IndexController)
    router.controllers.length.should eq 1
    router.controllers["IndexController"].is_a?(Class).should eq true
  end

  it "get method adds right route to @routes" do
    route = router.routes[0]
    route.controller.should eq "IndexController"
    route.action.should eq "hello"
    route.pattern.should eq "/index$"
  end

  it "returns HTTP::Response" do
    request    = Http::Request.new(HTTP::Request.new("GET", "/index"))
    router.call(request).should be_a Http::Response
  end

  it "checks if path route exists" do
    router.exists?("/index", "GET").should eq true
    expect_raises HttpMethodNotAllowed do
      router.exists?("/index", "PUT")
    end
  end
end