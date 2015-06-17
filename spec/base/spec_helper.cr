require "spec"
require "../../src/all"

class IndexController < Base::Controller
  actions :hello, :bye
  def hello
    html "Hello"
  end

  def bye
    html "Bye"
  end
end

class ViewController < Controller
  actions :index, :hello, :redirect

  def index
    html "Hello world!<img src='/assets/amethyst.jpg'>"
  end

  view "hello", "#{__DIR__}/views/", name
  def hello
    name = "Andrew"
    respond_to do |format|
      format.html { render "hello", name }
    end
  end

  def redirect
    respond_to do |format|
      format.html { redirect_to "user/45" }
    end
  end
end



