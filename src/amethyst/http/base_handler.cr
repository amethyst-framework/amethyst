class BaseHandler < HTTP::Handler

  def call(request : HTTP::Request, verbose=true)
    puts "[Amethyst #{Time.now}] #{request.method} #{request.path}" if verbose  #TODO move to Logger class
    response = HTTP::Response.new(200, "Welcome to Amethyst!")                  #TODO create Request and Response classes
  end
end
