# Creates the main folders for app bootstrapping
class MainGenerator

  def initialize
    FolderGenerator.new("controllers")
    FolderGenerator.new("views")
  end

end
