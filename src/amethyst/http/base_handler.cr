require "http"
class BaseHandler < HTTP::Handler

  def call(request : HTTP::Request)
    response = HTTP::Response.new(200, "Welcome to Amethyst! #{request.headers}")
  end
end
