require "../spec_helper"

class AssertionsTest < Minitest::Test
  
  describe Request do
    property! request
    property! base_request
    property! headers

    before do
      @headers = HTTP::Headers.new
      @headers["Content-type"] = ["text/plain"]
      @base_request = HTTP::Request.new("GET", "/", @headers)
      @request = Request.new(@base_request)
    end

    it "should be initialized properly" do
      assert_equal request.method,  base_request.method
      assert_equal request.path,	  base_request.path
      assert_equal request.headers, base_request.headers
      assert_equal request.body,		base_request.body
      assert_equal request.version,	base_request.version
    end
  end
end
