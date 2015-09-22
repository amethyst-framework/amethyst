require "./spec_helper"

describe Router do

  router     = Router.new
  request    = HttpHlp.req("GET", "/index")
  response   = HttpHlp.res(200, "Ok")
  controller = create_controller_instance(IndexController)
  controller.set_env(request, response)

  describe "#draw" do
    it "draws routes properly" do
      router.draw do
        get "/index/", "index#hello"
        register IndexController
      end
      router.routes[0].should be_a Amethyst::Dispatch::Route
    end
  end


  describe "#register" do
    it "registers controller" do
      router.register(IndexController)
      router.controllers.size.should eq 1
      router.controllers["IndexController"].is_a?(Class).should eq true
    end
  end


  describe Support::RoutesPainter do
    it "get method adds right route to @routes" do
      route = router.routes[0]
      route.controller.should eq "IndexController"
      route.action.should eq "hello"
      route.pattern.should eq "/index$"
    end
  end

  describe "#exists?" do
    it "return true if route path exists" do
      router.exists?("/index", "GET").should eq true
    end

    it "return false if route path doesn't exists" do
      router.exists?("/indexs", "GET").should eq false
    end

    it "raises HttpMethodNotAllowed if method not allowed" do
      expect_raises HttpMethodNotAllowed do
        router.exists?("/index", "PUT")
      end
    end

    it "raises HttpNotImplemented if method is not implemented" do
      expect_raises HttpNotImplemented do
        router.exists?("/index", "GETSS")
      end
    end
  end

  describe "#call" do

    it "returns HTTP::Response" do
      request = HttpHlp.req("GET", "/index")
      router.call(request).should be_a Http::Response
    end

    it "routes to default route if named route doesn't exists" do
      router     = Router.new
      request    = HttpHlp.req("GET", "/index/hello")
      response   = HttpHlp.res(200, "Ok")
      controller = create_controller_instance(IndexController)
      controller.set_env(request, response)
      router.draw do
        register IndexController
      end

      response = router.call(request)
      response.should be_a Http::Response
      response.body.should eq "Hello"
    end

    it "recognize default route with underscores and hyphens" do
      router     = Router.new
      request    = HttpHlp.req("GET", "/index/hello_you")
      response   = HttpHlp.res(200, "Ok")
      controller = create_controller_instance(IndexController)
      controller.set_env(request, response)
      router.draw do
        register IndexController
      end

      response = router.call(request)
      response.should be_a Http::Response
      response.body.should eq "Hello, you!"
    end
  end

  it "raises HttpNotImplemented if method is not implemented" do
    router     = Router.new
    request    = HttpHlp.req("GETSS", "/index/hello")
    response   = HttpHlp.res(200, "Ok")
    controller = create_controller_instance(IndexController)
    controller.set_env(request, response)
    router.draw do
      register IndexController
    end

    expect_raises HttpNotImplemented do
      router.call(request)
    end
  end
end
