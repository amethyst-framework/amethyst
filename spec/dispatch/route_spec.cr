require "./spec_helper"



describe Route do

  route_strict  = Route.new("/index/", "IndexController", "hello")
  route_strict.add_request_method("GET")
  root_route    = Route.new("/", "IndexController", "show")
  root_route.add_request_method("POST")
  route_params  = Route.new("/users/show/:id", "UsersController", "show")
  route_params.add_request_method("PUT")
  route_match   = Route.new("/index", "IndexController", "all")
  route_match.add_request_method("DELETE")

  it "instantiates with simple path properly" do
    route_strict.pattern.should eq "/index$"
    route_strict.length.should eq 2
    route_strict.controller.should eq "IndexController"
    route_strict.action.should eq "hello"
  end

  it "properly extracts path params" do
    route_params.pattern.should eq "/users/show/:id"
    route_params.params("/users/show/5").should eq ({"id" => "5"})
    route_params.length.should eq 4
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

  it "matches a given path with strict route" do
    route_strict.matches?("/index", "GET").should eq true
    expect_raises HttpMethodNotAllowed do
      route_strict.matches?("/index", "PUT")
    end
    route_strict.matches?("/indexsd", "GET").should eq false
    route_strict.matches?("/index/", "GET").should eq true
    route_strict.matches?("/index/1/ddd/", "GET").should eq false
  end

  it "mathes a given path with a matching route" do
    route_match.matches?("/index", "DELETE").should eq true
    expect_raises HttpMethodNotAllowed do
      route_match.matches?("/index", "PUT")
    end
    route_match.matches?("/indexsd", "DELETE").should eq true
    route_match.matches?("/index/", "DELETE").should eq true
    route_match.matches?("/index/1/ddd/", "DELETE").should eq false
  end

  it "mathes a given path with a params route" do
    route_params.matches?("/users/show/10", "PUT").should eq true
    route_params.matches?("/users/show/10/", "PUT").should eq true
    route_params.matches?("users/show/10/you", "PUT").should eq false
    route_params.matches?("users/show", "PUT").should eq false
    route_params.matches?("users/show/", "PUT").should eq false
    expect_raises HttpMethodNotAllowed do
      route_params.matches?("/users/show/10", "DELETE")
    end
  end

  it "mathes root route" do
    root_route.matches?("/", "POST").should eq true
    root_route.matches?("/d", "POST").should eq false
  end

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

  it "returns params hash of given path" do
    route = Route.new("/users/:id", "UsersController", "id")
    route.params("/users/45").should eq Hash{"id" => "45"}
  end
end