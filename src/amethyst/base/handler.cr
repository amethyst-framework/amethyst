class Handler

  def initialize(app)
    @app = app
  end

  def call(base_request : HTTP::Request)
    request  = Http::Request.new(base_request)
    response = @app.call(request)
    response.build
  end
end
