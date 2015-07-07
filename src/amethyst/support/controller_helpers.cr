module ControllerHelpers
  private def html(body : String, status=200)
    @response.set(status, body)
    @response.header("Content-Type", "text/html")
  end

  private def text(body : String, status=200)
    @response.set(status, body)
    @response.header("Content-Type", "text/plain")
  end

  private def json(body : String, status=200)
    @response.set(status, body)
    @response.header("Content-Type", "application/json")
  end

  private def redirect_to(location : String)
    @response.header "Location", location
    @response.status = 303
  end
end