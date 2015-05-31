require "../spec_helper"
app = App.new() 
app.port = 8080

describe App do

  it "has right name" do
    app.name.should eq File.basename(__FILE__).gsub(/.\w+\Z/, "")
  end
end
