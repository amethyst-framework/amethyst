# Folder generator for app bootstrapping
class FolderGenerator

  def initialize(folder_name)
    Dir.mkdir folder_name unless Dir.exists? folder_name
  end

end
