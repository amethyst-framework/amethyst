require "./spec_helper"

describe Config do

	Config::INSTANCE.configure do |conf|
    conf.name   "name"
    conf.string "string"
  end

  it "sets keys and values properly" do
    Config::INSTANCE.name.should eq "name"
    Config::INSTANCE.string.should eq "string"
  end

  it "raises exception when key not found" do
    expect_raises Exception, "No config key with name :surname" do
      Config::INSTANCE.surname
    end
  end
end