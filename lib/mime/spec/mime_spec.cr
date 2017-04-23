require "spec"
require "../src/mime"

describe "mime helper" do
  describe "from_ext" do
    it "provides the mime-type for an extension" do
      Mime.from_ext("json").should eq("application/json")
      Mime.from_ext("jpg").should eq("image/jpeg")
      Mime.from_ext("js").should eq("application/javascript")
    end

    it "returns nil when there isn't a match" do
      Mime.from_ext("not an extension").should be(nil)
      Mime.from_ext("also not an extension").nil?.should be_true
    end

    it "accepts symbols as extension" do
      Mime.from_ext(:js).should eq("application/javascript")
    end
  end

  describe "to_ext" do
    it "provides the extension for a mimetype" do
      Mime.to_ext("application/json").should eq("json")
      Mime.to_ext("image/jpeg").should eq("jpeg")
      Mime.to_ext("application/javascript").should eq("js")
    end

    it "returns nil when there isn't a match" do
      Mime.to_ext("not a mime type").should be(nil)
      Mime.to_ext("also not a mime").nil?.should be_true
    end
  end

end
