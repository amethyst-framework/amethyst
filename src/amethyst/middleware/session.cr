require "./middleware"
class Session < Middleware::Base 

  def initialize
    super()
    @session_pool = Base::App.session
  end

  def call(request) : Http::Response
    found, session_id = get_session(request)
    response = @app.call(request)
    set_session(response, session_id) if !found
    return response
  end 

  def get_session(request)
    cookies = request.headers["Cookie"].split(";")
    
    session_id = nil
    cookies.each do |cookie|
      if cookie.includes?("session_id=")
        session_id = cookie.split("=")[1]
        break
      end
    end

    unless session_id
      session_id = @session_pool.generate_sid("session_id")
      cookies << "session_id=" + session_id
      request.headers["Cookie"] = cookies.join(";")
      return false, session_id
    end
    
    return true, session_id
  end

  def set_session(response, session_id)
    response.headers["Set-Cookie"] = "session_id=#{session_id}"
  end
end
