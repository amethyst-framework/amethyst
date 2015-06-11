class ShowExceptions < Middleware::Base

  def call(request : Http::Request) : Http::Response
    begin
      response = @app.call(request)
      p typeof(response)
      response.set(200, "OK")
    rescue httpexception : HttpException
      response.set(httpexception.status, httpexception.msg)
    rescue ex : Exception
      if Base::App.settings.environment == "development"
      	response = Http::Response.new(200, "ERROR: #{ex.message}\n\n#{ex.backtrace.join '\n'}\n")
      else
      	response = Response.new(404, "404 Not Found")
      end
    end
    response
  end
end

#TODO : Make an exception controller and views