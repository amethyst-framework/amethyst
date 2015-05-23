module Amethyst
  class Application

    def initialize(@name= __FILE__, @port=8080)
      @app_name ||= File.basename(@name).gsub(/.\w+\Z/, "")
      @run_string = "[Amethyst #{Time.now}] running app \"#{@app_name}\" at http://127.0.0.1:#{port}"
    end

    def serve()
      puts @run_string
      server = HTTP::Server.new @port, Http::BaseHandler.new
      server.listen
    end
  end
end
