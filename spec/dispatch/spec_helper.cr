require "../spec_helper"

class IndexController < Base::Controller
  actions :hello, :bye
  def hello
    html "Hello"
  end

  def bye
    html "Bye"
  end
end