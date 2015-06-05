class Static < Middleware::Base

	def initialize
		@app = self
	end

	def call(request)
		if File.extname(request.path) == ""
			@app.call(request)
		else
			app_path = Base::App.settings.app_dir
			path_to_file = app_path+request.path
			response = Http::Response.new(404, "File not found")
			if File.exists?(path_to_file)
				response = Http::Response.new(200, File.read(path_to_file))
				response.headers["Content-type"] = mime_type(path_to_file)
			end
			response
		end
	end

	private def mime_type(path)
    case File.extname(path)
    when ".jpg", "jpeg" then "image/jpeg"
    when ".txt" then "text/plain"
    when ".htm", ".html" then "text/html"
    when ".css" then "text/css"
    when ".js" then "application/javascript"
    else "application/octet-stream"
    end
  end
end