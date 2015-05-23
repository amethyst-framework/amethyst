require "./spec_helper"
include Amethyst

app = Amethyst::Application.new()
app.port = 8000

describe Application do
  it "has right name" do
    app.name.should eq File.basename(__FILE__).gsub(/.\w+\Z/, "")
  end
end
