require "./spec_helper"

describe App do

	

  it "has right name" do
  	app      = Base::App.new() 
	app.port = 8080
    app.name.should eq File.basename(__FILE__).gsub(/.\w+\Z/, "")
  end
end
