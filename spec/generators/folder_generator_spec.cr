require "./spec_helper"

describe FolderGenerator do

  it "creates a new folder with given name" do
    folder_name = "a_folder"
    FolderGenerator.new folder_name
    Dir.exists?(Base::App.settings.app_dir + folder_name).should eq true
    # Cleanup the test folder
    Dir.rmdir(Base::App.settings.app_dir + folder_name)
  end

end
