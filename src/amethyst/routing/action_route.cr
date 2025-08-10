require "./route"
require "../controller_dispatcher"
require "../http/request" 
require "../http/response"

module Amethyst
  module Routing
    # Route that dispatches to controller action via string names
    class ActionRoute < BaseRoute
      getter controller_name : String
      getter action_name : String
      
      def initialize(@method, @path, @controller_name, @action_name, @name = nil, @middleware = [] of Middleware)
        super(@method, @path, @name, @middleware)
      end
      
      def call(context : HTTP::Context)
        # Extract parameters from the matched route
        request = Http::Request.from_http_context(context)
        
        # Get route parameters from the context (set by router)
        params = {} of String => String
        if route_params = context.get?("route_params")
          params = route_params.as(Hash(String, String))
        end
        
        # Dispatch to controller and get response
        response = ControllerDispatcher.instance.dispatch(@controller_name, @action_name, request, params)
        
        # Convert our Http::Response to HTTP::Server response
        context.response.status_code = response.status_code
        context.response.headers.merge!(response.headers)
        context.response.print(response.content)
      end
    end
  end
end