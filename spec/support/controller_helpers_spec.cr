require "./spec_helper"

class HelpersTestController < Base::Controller
    actions :html_test, :text_test, :json_test, :redirect_to_test

    def html_test
      html "Not found", status: 404
    end

    def text_test
      text "Hello world"
    end

    def json_test
      json "Hello world"
    end

    def json_test_with_hash
      json({:hello => "World"}.as(Hash(Symbol, String)))
    end

    def redirect_to_test
      redirect_to "google.com"
    end
  end

describe Support::ControllerHelpers do

  helpers_test_controller = create_controller_instance HelpersTestController

  describe "#html" do
    it "should set status, body and 'Content-Type' header" do
      helpers_test_controller.html_test
      helpers_test_controller.body.should eq "Not found"
      helpers_test_controller.response.status.should eq 404
      helpers_test_controller.response.headers["Content-Type"].should eq "text/html"
    end
  end

  describe "#text" do
    it "should set status, body and 'Content-Type' header" do
      helpers_test_controller.text_test
      helpers_test_controller.body.should eq "Hello world"
      helpers_test_controller.response.status.should eq 200
      helpers_test_controller.response.headers["Content-Type"].should eq "text/plain"
    end
  end

  describe "#json" do
    it "should set status, body and 'Content-Type' header" do
      helpers_test_controller.json_test
      helpers_test_controller.body.should eq "Hello world"
      helpers_test_controller.response.status.should eq 200
      helpers_test_controller.response.headers["Content-Type"].should eq "application/json"
    end

    it "should set status, body and 'Content-Type' header" do
      helpers_test_controller.json_test_with_hash
      helpers_test_controller.body.should eq "{\"hello\":\"World\"}"
      helpers_test_controller.response.status.should eq 200
      helpers_test_controller.response.headers["Content-Type"].should eq "application/json"
    end
  end

  describe "#redirect_to" do
    it "should set status, body and 'Content-Type' header" do
      helpers_test_controller.redirect_to_test
      helpers_test_controller.response.status.should eq 303
      helpers_test_controller.response.headers["Location"].should eq "google.com"
    end
  end
end
