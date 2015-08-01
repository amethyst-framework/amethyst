require "./spec_helper"

describe Base::View do

  describe "#button_to" do
    it "should create a button form" do
      view = Base::View.new
      button = view.button_to "send", controller: :user, action: :login
      button.should eq "<form method=\"post\" action=\"/user/login\" class=\"button_to\"><input value=\"send\" type=\"submit\" class=\"\"></form>"
    end
  end

  describe "#check_box" do
    it "should create a checkbox" do
      view = Base::View.new
      checkbox = view.check_box "brand"
      checkbox.should eq "<input checked=\"checked\" type=\"checkbox\" id=\"\" name=\"brand\" value=\"1\">"
    end
  end
end
