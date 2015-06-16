require "./spec_helper"
require "minitest/autorun"

describe Base::App do
  let(:app) { Base::App.new }

  describe "initialize method" do
    it "should set app name" do
      app.name.must_equal "application_spec"
    end

    it "should set default middleware" do
      Middleware::MiddlewareStack::INSTANCE.must_include Middleware::ShowExceptions
      Middleware::MiddlewareStack::INSTANCE.must_include Middleware::Cookies
      Middleware::MiddlewareStack::INSTANCE.must_include Middleware::Static
    end
  end

  describe "class methods delegate shortcuts to other objects" do
    it "self.settings" do
      Base::App.settings.must_be_same_as Base::Config::INSTANCE
    end

    it "self.routes" do
      Base::App.routes.must_be_same_as Dispatch::Router::INSTANCE
    end

    it "self.logger" do
      Base::App.logger.must_be_same_as Base::Logger::INSTANCE
    end

    it "self.middleware" do
      Base::App.middleware.must_be_same_as Middleware::MiddlewareStack::INSTANCE
    end
  end
end
