require "./middleware"

module Amethyst
  module Middleware
    class Session < Middleware::Base 
      @session_pool : Amethyst::Session::Pool

      def initialize(@app = self)
        @session_pool = Amethyst::Base::App.session
      end

      def call(request) : Http::Response
        found, session_id = get_session(request)
        response = @app.call(request)
        set_session(response, session_id) if !found
        return response
      end 

      def get_session(request)
        cookies = [] of String
        if request.headers.has_key?("Cookie")
          cookies = request.headers["Cookie"].split(";")
        end
        
        session_id = nil
        cookies.each do |cookie|
          if cookie.includes?("sid=")
            session_id = cookie.split("=")[1]
            break
          end
        end

        unless session_id
          session_id = @session_pool.generate_sid
          cookies << "sid=" + session_id
          request.headers["Cookie"] = cookies.join(";")
          return false, session_id
        end
        
        return true, session_id
      end

      def set_session(response, session_id)
        response.headers["Set-Cookie"] = "sid=#{session_id}"
      end
    end
  end
end
