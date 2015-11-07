require "../spec_helper"
require "../../src/all"

class ViewController < Controller
  actions :index, :hello, :redirect

  def index
    html "Hello world!<img src='/assets/amethyst.jpg'>"
  end

  view "hello", "#{__DIR__}/views/"
  def hello
    @name = "Andrew"
    respond_to do |format|
      format.html { render "hello" }
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
