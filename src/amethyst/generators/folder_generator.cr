# Folder generator for app bootstrapping
class FolderGenerator

  def initialize(folder_name)
    folder_path = Base::App.settings.app_dir + folder_name
    Dir.mkdir folder_path unless Dir.exists? folder_path
  end

end
