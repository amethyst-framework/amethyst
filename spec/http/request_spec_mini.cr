#require "./spec_helper"

#class AssertionsTest < Minitest::Test
  
#  describe Request do
#      let(:headers) do 
#        headers = HTTP::Headers.new
#        headers["Content-type"] = ["text/plain"]
#        headers
#      end
#        let(:base_request) { HTTP::Request.new("GET", "/", headers) }
#        let(:request)      { Request.new(base_request) }
#
#    it "should be initialized properly" do
#      assert_equal request.method,  base_request.method
#      assert_equal request.path,	  base_request.path
#      assert_equal request.headers, base_request.headers
#      assert_equal request.body,		base_request.body
#      assert_equal request.version,	base_request.version
#    end
#  end
#end
