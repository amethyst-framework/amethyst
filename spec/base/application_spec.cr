require "./spec_helper"

describe App do

  it "has right name" do
    app      = Base::App.new()
    app.port = 8080
    app.name.should eq File.basename(__FILE__).gsub(/.\w+\Z/, "")
  end

  it "class methods delegate shortcuts to other objects" do
    App.settings.should be_a Base::Config
    App.routes.should be_a   Dispatch::Router
    App.logger.should be_a   Base::Logger
    App.middlewares.should be_a Middleware::MiddlewareStack
  end

  it "loads middleware to a MiddlewareStack" do
    App.use TestMiddleware
    App.middlewares.any?.should eq true
    puts App.middlewares
    App.middlewares.includes?(TestMiddleware).should eq true
  end 
end
