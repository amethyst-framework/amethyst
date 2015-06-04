class ShowExceptions < Middleware::Base
  def call(request)
    begin
      response = @app.call(request)
      response
    rescue ex : Exception
      Http::Response.new(200, "ERROR: #{ex.message}\n#{ex.backtrace.join '\n'}\n")
    end
  end
end