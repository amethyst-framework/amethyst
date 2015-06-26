require "./spec_helper"

describe Base::View do

	describe "#button_to" do
		it "should create button form" do
			view = Base::View.new
			button = view.button_to "Send", controller: :user, action: :login
		  button.should eq "
    <form method='post' action='/user/login' class='button_to'>
      <input value='Send' type='submit' class='' />
    </form>"	
		end
	end
end