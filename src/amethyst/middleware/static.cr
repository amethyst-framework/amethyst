module Amethyst
  module Middleware
    class Static < Middleware::Base
      @static_dirs : Array(String)

      def initialize(@app : Middleware::Base | Routing::OptimizedRouter? = nil)
        super(@app)
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
        ext = File.extname(path)
        mime_type = case ext
        when ".html", ".htm" then "text/html"
        when ".css" then "text/css"
        when ".js" then "application/javascript"
        when ".json" then "application/json"
        when ".png" then "image/png"
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".gif" then "image/gif"
        when ".svg" then "image/svg+xml"
        when ".txt" then "text/plain"
        when ".xml" then "application/xml"
        when ".pdf" then "application/pdf"
        else "application/octet-stream"
        end
        [mime_type]
       end
    end
  end
end
