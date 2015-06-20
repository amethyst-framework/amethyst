require "./spec_helper"
# require "minitest/autorun"

describe Base::App do


  describe "#initialize" do
    app = Base::App.new

    it "should set app name" do
      app.name.should eq "application_spec"
    end

    it "should set app directory" do
      Base::App.settings.app_dir.should eq ENV["PWD"]
    end

    it "should set default middleware" do
      Middleware::MiddlewareStack::INSTANCE.includes?(Middleware::ShowExceptions).should be_true
      Middleware::MiddlewareStack::INSTANCE.includes?(Middleware::Static).should be_true
    end
  end


  describe "#get_app_namespace" do
    it "should return namespace of initialized app" do
      my_app = My::Inner::App.new
      My::Inner::App.settings.namespace.should eq "My::Inner::"
    end

    it "should return empty string if app is in global namespace" do
      global_app = GlobalApp.new
      GlobalApp.settings.namespace.should eq ""
    end
  end


  describe "shortcuts" do
    it "self.settings" do
      Base::App.settings.should be Base::Config::INSTANCE
    end

    it "self.routes" do
      Base::App.routes.should be Dispatch::Router::INSTANCE
    end

    it "self.logger" do
      Base::App.logger.should be Base::Logger::INSTANCE
    end

    it "self.middleware" do
      Base::App.middleware.should be Middleware::MiddlewareStack::INSTANCE
    end
  end


  describe "self#use" do
    Base::App.use TestMiddleware
    it " delegates to MiddlewareStack" do
      App.middleware.includes?(TestMiddleware).should be_true
    end
  end
end
