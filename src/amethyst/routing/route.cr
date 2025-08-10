require "http"
require "../http/request"
require "../http/response"

module Amethyst
  module Routing
    # Type-safe route representation
    abstract class BaseRoute
      getter method : String
      getter path : String
      getter name : String?
      getter middleware : Array(Middleware)
      getter param_names : Array(String)
      getter regex : Regex
      
      def initialize(@method, @path, @name = nil, @middleware = [] of Middleware)
        @param_names = extract_param_names(@path)
        @regex = compile_path_regex(@path)
      end
      
      # Check if route matches request
      def matches?(request_path : String, request_method : String) : NamedTuple?
        return nil unless @method == request_method
        
        if match = @regex.match(request_path)
          params = {} of String => String
          
          @param_names.each_with_index do |name, index|
            if value = match[index + 1]?
              params[name] = value
            end
          end
          
          {params: params}
        end
      end
      
      abstract def call(context : HTTP::Context)
      
      private def extract_param_names(path : String) : Array(String)
        names = [] of String
        path.scan(/:(\w+)/).each do |match|
          names << match[1]
        end
        names
      end
      
      private def compile_path_regex(path : String) : Regex
        # Convert path with :params to regex
        # /users/:id/posts/:post_id -> /users/([^/]+)/posts/([^/]+)
        pattern = path.gsub(/:(\w+)/) { "([^/]+)" }
        Regex.new("^#{pattern}$")
      end
    end
    
    # Route that dispatches to controller action
    class Route < BaseRoute
      getter controller : Controller.class
      getter action : Symbol
      
      def initialize(@method, @path, @controller, @action, @name = nil, @middleware = [] of Middleware)
        super(@method, @path, @name, @middleware)
      end
      
      def call(context : HTTP::Context)
        controller_instance = @controller.new(context)
        controller_instance.call(@action)
      end
      
      # Generate OpenAPI spec for this route
      def to_openapi
        {
          path: @path,
          method: @method.downcase,
          operationId: "#{@controller.name.split("::").last.underscore}_#{@action}",
          tags: [@controller.name.split("::").last.gsub(/Controller$/, "")],
          parameters: @param_names.map do |name|
            {
              name: name,
              in: "path",
              required: true,
              schema: {type: "string"}
            }
          end
        }
      end
    end
    
    # Route that calls a block directly
    class BlockRoute < BaseRoute
      getter handler : Proc(HTTP::Server::Context, Nil)
      
      def initialize(@method, @path, @handler, @name = nil, @middleware = [] of Middleware)
        super(@method, @path, @name, @middleware)
      end
      
      def call(context : HTTP::Context)
        @handler.call(context)
      end
    end
    
    # Compiled routes for fast lookup
    class CompiledRoutes
      @routes : Array(BaseRoute)
      @route_map : Hash(String, BaseRoute)
      
      def initialize(@routes)
        @route_map = {} of String => BaseRoute
        
        # Build lookup map for named routes
        @routes.each do |route|
          if name = route.name
            @route_map[name] = route
          end
        end
      end
      
      # Find matching route for request
      def find(path : String, method : String) : Tuple(BaseRoute, Hash(String, String))?
        @routes.each do |route|
          if match_data = route.matches?(path, method)
            return {route, match_data[:params]}
          end
        end
        nil
      end
      
      # Get route by name (for URL helpers)
      def get(name : String) : BaseRoute?
        @route_map[name]?
      end
      
      # Generate OpenAPI specification
      def to_openapi
        paths = {} of String => Hash(String, JSON::Any)
        
        @routes.each do |route|
          if route.is_a?(Route)
            path_item = paths[route.path] ||= {} of String => JSON::Any
            path_item[route.method.downcase] = JSON.parse(route.to_openapi.to_json)
          end
        end
        
        {
          openapi: "3.0.0",
          info: {
            title: "API Documentation",
            version: "1.0.0"
          },
          paths: paths
        }
      end
    end
  end
end