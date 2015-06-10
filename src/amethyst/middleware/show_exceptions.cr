class ShowExceptions < Middleware::Base

  def call(request : Http::Request)
    begin
      response = @app.call(request)
      response
    rescue ex : Exception
      if Base::App.settings.environment == "development"
      	Http::Response.new(200, "ERROR: #{ex.message}\n\n#{ex.backtrace.join '\n'}\n")
      else
      	Http::Response.new(404, "404 Not Found")
      end
    end
  end
end