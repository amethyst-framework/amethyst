require "../spec_helper"

route = Route.new("/index/", "IndexController", "hello")
route2 = Route.new("/users/show/:id", "UsersController", "show")

describe Route do

  it "instantiates with simple path properly" do
    route.pattern.should eq "/index"
    route.length.should eq 2
    route.controller.should eq "IndexController"
    route.action.should eq "hello"
  end

  it "instantiates with path with params" do
    route2.pattern.should eq "/users/show/:id"
    route2.get_params("/users/show/5").should eq ({"id" => "5"})
    route2.length.should eq 4
  end

  it "matches a given path" do
    route.matches?("/index").should eq true
    route.matches?("/index/").should eq true
    route.matches?("/index/1/ddd/").should eq false
    route2.matches?("/users/show/10").should eq true
    route2.matches?("users/show/hello/user").should eq false
    route2.matches?("users/show").should eq false
  end
end