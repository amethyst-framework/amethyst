module Amethyst
  class Application
    property port
    property name
    property verbose

    def initialize(name= __FILE__, @port=8080, verbose=true)
      @name ||= File.basename(name).gsub(/.\w+\Z/, "")
      @run_string = "[Amethyst #{Time.now}] serving application \"#{@name}\" at http://127.0.0.1:#{port}" #TODO move to Logger class
      @verbose = verbose
    end

    def serve()
      puts @run_string if @verbose
      server = HTTP::Server.new @port, Http::BaseHandler.new()
      server.listen
    end
  end
end
