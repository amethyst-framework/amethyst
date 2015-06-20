class Static < Middleware::Base

  def initialize
    @static_dirs = Base::App.settings.static_dirs
    @app = self
  end

  def call(request) : Http::Response
    if File.extname(request.path) == ""
      response = @app.call(request)
    else
      app_path = Base::App.settings.app_dir
      path_to_file = app_path+request.path
      dir = File.dirname(path_to_file)
      response = Http::Response.new(404, "File not found")
      if static_dir_exists?(dir)
        response = Http::Response.new(200, File.read(path_to_file))
        response.headers["Content-type"] = mime_type(path_to_file)
      end
    end
    response
  end

  def static_dir_exists?(dirpath)
    dirpath = dirpath.split "/"
    dirpath = dirpath.join "/" 
    exists = false
    @static_dirs.each do |dir|
      dir = dir.split "/"
      dir = dir.join "/"
      dir = Base::App.settings.app_dir+dir
      regexp = Regex.new "^#{dir}\/.*"
      match = regexp.match(dirpath+"/")
      exists = true if match
      break if exists
    end
    exists
  end

  private def mime_type(path)
    mime_type = "text/plain"
    mime_type = Mime.from_ext(File.extname(path).gsub(".", "")) as String
   end
end
