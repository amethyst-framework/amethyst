require "./spec_helper"

describe FolderGenerator do

  it "creates a new folder with given name" do
    FolderGenerator.new "some"
    Dir.exists?("some").should eq true
    # Cleanup the test folder
    Dir.rmdir("some")
  end

end
