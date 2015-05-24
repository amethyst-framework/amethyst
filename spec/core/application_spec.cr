require "../spec_helper"

app = Application.new() 
app.port = 8080

describe Application do

  it "has right name" do
    app.name.should eq File.basename(__FILE__).gsub(/.\w+\Z/, "")
  end
end
