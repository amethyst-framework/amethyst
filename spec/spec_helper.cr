require "spec"
#require "minitest/autorun"
#require "webmock"

require "../src/all"

class IndexController < BaseController
  def hello(request)
    HTTP::Response.new(200, "Hello")
  end

  def actions
    add :hello
  end
end