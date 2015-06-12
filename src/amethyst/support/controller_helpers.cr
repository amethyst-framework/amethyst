module ControllerHelpers
  private def html(body : String)
    @response.set(200, body)
    @response.header("Content-Type", "text/html")
  end

  private def text(body : String)
    @response.set(200, body)
    @response.header("Content-Type", "text/plain")
  end

  private def json(body : String)
    @response.set(200, body)
    @response.header("Content-Type", "application/json")
  end

  private def redirect_to(location : String)
    @response.header "Location", location
    @response.status = 303
  end
end