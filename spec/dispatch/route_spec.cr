require "./spec_helper"



describe Route do

  strict_route  = Route.new("/index/", "IndexController", "hello")
  strict_route.add_request_method("GET")

  root_route    = Route.new("/", "IndexController", "show")
  root_route.add_request_method("POST")

  paramered_route  = Route.new("/users/show/:id", "UsersController", "show")
  paramered_route.add_request_method("PUT")

  matched_route   = Route.new("/index", "IndexController", "all")
  matched_route.add_request_method("DELETE")

  describe "#initialize" do

    it "instantiates route properly" do
      strict_route.pattern.should eq "/index$"
      strict_route.length.should eq 2
      strict_route.controller.should eq "IndexController"
      strict_route.action.should eq "hello"
    end

    it "properly extracts path params" do
      paramered_route.pattern.should eq "/users/show/:id"
      paramered_route.params("/users/show/5").should eq ({"id" => "5"})
      paramered_route.length.should eq 4
    end
  end

  describe "#matches?" do

    it "matches a given path with strict route" do
      strict_route.matches?("/index", "GET").should eq true
      expect_raises HttpMethodNotAllowed do
        strict_route.matches?("/index", "PUT")
      end
      strict_route.matches?("/indexsd", "GET").should eq false
      strict_route.matches?("/index/", "GET").should eq true
      strict_route.matches?("/index/1/ddd/", "GET").should eq false
    end

    it "mathes a given path with a matching route" do
      matched_route.matches?("/index", "DELETE").should eq true
      expect_raises HttpMethodNotAllowed do
        matched_route.matches?("/index", "PUT")
      end
      matched_route.matches?("/indexsd", "DELETE").should eq true
      matched_route.matches?("/index/", "DELETE").should eq true
      matched_route.matches?("/index/1/ddd/", "DELETE").should eq false
    end

    it "mathes a given path with a params route" do
      paramered_route.matches?("/users/show/10", "PUT").should eq true
      paramered_route.matches?("/users/show/10/", "PUT").should eq true
      paramered_route.matches?("users/show/10/you", "PUT").should eq false
      paramered_route.matches?("users/show", "PUT").should eq false
      paramered_route.matches?("users/show/", "PUT").should eq false
      expect_raises HttpMethodNotAllowed do
        paramered_route.matches?("/users/show/10", "DELETE")
      end
    end

    it "mathes root route" do
      root_route.matches?("/", "POST").should eq true
      root_route.matches?("/d", "POST").should eq false
    end
  end


  describe "#add_request_method" do

    it "raises an exception if unsupported method given" do
      route = Route.new("/", "IndexController", "hello")
      expect_raises UnsupportedHttpMethod do
        route.add_request_method("SOME")
      end
    end

    it "responds to added http methods" do
      route = Route.new("/", "IndexController", "hello")
      route.add_request_method("GET")
      route.add_request_method("PUT")
      route.matches?("/", "GET").should eq true
      route.matches?("/", "PUT").should eq true
      expect_raises HttpMethodNotAllowed do
        route.matches?("/", "DELETE")
      end
    end
  end

  describe "#params" do
    it "returns params hash of given path" do
      route = Route.new("/users/:id", "UsersController", "id")
      route.params("/users/45").should eq Hash{"id" => "45"}
    end
  end

  it "respond to added http methods that allowed" do
      route = Route.new("/", "IndexController", "hello")
      route.add_request_method("GET")
      route.add_request_method("PUT")
      route.matches?("/", "GET").should eq true
      route.matches?("/", "PUT").should eq true
      expect_raises HttpMethodNotAllowed do
        route.matches?("/", "DELETE")
      end
      expect_raises HttpNotImplemented do
        route.matches?("/", "CONNECT")
      end
    end
end
