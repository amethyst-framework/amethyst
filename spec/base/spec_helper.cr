require "spec"
require "../../src/all"

class IndexController < Base::Controller
  actions :hello, :bye, :hello_you
  def hello
    html "Hello"
  end

  def hello_you
    html "Hello, you!"
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

module My
  module Inner
    class App < Base::App
    end
  end
end

class GlobalApp < Base::App
end


