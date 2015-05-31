require "./spec_helper"

describe Router do

  router     = Router.new
  request    = Amethyst::Http::Request.new(HTTP::Request.new("GET", "/index"))
  response   = Amethyst::Http::Response.new(200, "Ok")
  controller = IndexController.new(request, response)

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

  it "get method add right route to @routes" do
    route = router.routes[0]
    route.controller.should eq "IndexController"
    route.action.should eq "hello"
    route.pattern.should eq "/index$"
  end

  it "returns HTTP::Response" do
    router.call(request).should be_a Amethyst::Http::Response
  end
end