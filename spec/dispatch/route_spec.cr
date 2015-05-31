require "./spec_helper"



describe Route do

  route_strict  = Route.new("/index/", "IndexController", "hello")
  root_route    = Route.new("/", "IndexController", "show")
  route_params  = Route.new("/users/show/:id", "UsersController", "show")
  route_match   = Route.new("/index", "IndexController", "all")

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

  it "matches a given path with stict route" do
    route_strict.matches?("/index").should eq true
    route_strict.matches?("/indexsd").should eq false
    route_strict.matches?("/index/").should eq true
    route_strict.matches?("/index/1/ddd/").should eq false
  end

  it "mathes a given path with a matching route" do
    route_match.matches?("/index").should eq true
    route_match.matches?("/indexsd").should eq true
    route_match.matches?("/index/").should eq true
    route_match.matches?("/index/1/ddd/").should eq false
  end

  it "mathes a given path with a params route" do
    route_params.matches?("/users/show/10").should eq true
    route_params.matches?("/users/show/10/").should eq true
    route_params.matches?("users/show/10/you").should eq false
    route_params.matches?("users/show").should eq false
    route_params.matches?("users/show/").should eq false
  end

  it "mathes root route" do
    root_route.matches?("/").should eq true
    root_route.matches?("/d").should eq false
  end
end