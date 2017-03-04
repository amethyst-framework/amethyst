module Amethyst
  module Middleware
    class Static < Middleware::Base
      @static_dirs : Array(String)

      def initialize(@app = self)
        @static_dirs = Amethyst::Base::App.settings.static_dirs
      end

      def call(request) : Http::Response
        if File.extname(request.path) == ""
          response = @app.call(request)
        else
          response = Http::Response.new(404, "File not found")
          if path_to_file = find_static_file(request.path)
            response = Http::Response.new(200, File.read(path_to_file))
            response.headers["Content-type"] = mime_type(path_to_file)
          end
        end
        response
      end

      def find_static_file(file)
        result = nil
        @static_dirs.each do |dir|
          dir = dir.split "/"
          dir = dir.join "/"
          dir = Amethyst::Base::App.settings.app_dir+dir+file
          if File.file?(dir)
            result = dir
            break
          end
        end
        return result
      end

      private def mime_type(path) : Array(String)
        mime_type = "text/plain"
        mime_type = [Mime.from_ext(File.extname(path).gsub(".", "")).as(String)]
       end
    end
  end
end
