class Static < Middleware::Base

	def initialize
		@app = self
	end

	def call(request) : Http::Response
		if File.extname(request.path) == ""
			response = @app.call(request)
		else
			app_path = Base::App.settings.app_dir
			path_to_file = app_path+request.path
			response = Http::Response.new(404, "File not found")
			if File.exists?(path_to_file)
				response = Http::Response.new(200, File.read(path_to_file))
				response.headers["Content-type"] = mime_type(path_to_file)
			end
		end
    response
	end

	private def mime_type(path)
    mime_type = "text/plain"
    mime_type = Mime.from_ext(File.extname(path).gsub(".", "")) as String
   end
end