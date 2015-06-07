module ControllerHelpers
  private def html(body : String)
    @response.body = body
    @response.header("Content-Type", "text/html")
  end

  private def text(body : String)
    @response.body = body
    @response.header("Content-Type", "text/plain")
  end

  private def json(body : String)
    @response.body = body
    @response.header("Content-Type", "application/json")
  end
end