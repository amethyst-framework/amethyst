require "./spec_helper"

class HelpersTestController < Base::Controller
		actions :html_test, :text_test, :json_test, :redirect_to_test

		def html_test
			html "Not found", status: 404
		end

		def text_test
			html "Hello world"
		end

		def json_test
			html "Hello world"
		end

		def redirect_to_test
			html "Hello world"
		end
	end

describe Support::ControllerHelpers do

	helpers_test_controller = create_controller_instance HelpersTestController

	describe "#html" do
		it "should set status, body and header" do
			helpers_test_controller.html_test
			helpers_test_controller.body.should eq "Not found"
			helpers_test_controller.response.status.should eq 404
		end
	end
end
