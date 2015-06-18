require "./spec_helper"

describe Params do
	
	describe "#initialize" do
	  it "should set default value" do
	  	params = Params.new
	  	params["id"].should eq ""

	  	params = Params.new(" ")
	  	params["id"].should eq " "
	  end
	end

  
  describe "#from_hash" do
		it "should set Params from Hash(String, String)" do
			params = Params.new
			params.from_hash Hash{ "id" => "5", "name" => "Amethyst"}
			params["id"].should eq "5"
			params.length.should eq 2
		end

		it "should cast keys and values to String" do
			params = Params.new
			params.from_hash Hash{ "id" => 5, :name => "Amethyst"}
			params["id"].should eq "5"
			# params["name"].should eq "Amethyst"
			params.length.should eq 2
		end
	end


	describe "#[](key)" do
		it "should acess value through Symbol key" do
			params = Params.new
			params[:id].should eq ""
		end

		it "values acessed through Symbol and String keys should be the same" do
			params = Params.new
			params.from_hash Hash{ "id" => "5", "name" => "Amethyst"}
			params[:id].should eq params["id"] 
		end
	end


	describe "#[](key)" do
		it "should cast value and key to String" do
			params = Params.new
			params[:id] = 5
			params["id"].should eq "5"
		end
	end
end