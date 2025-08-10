module Amethyst
  module Routing
    # Type-safe route DSL with compile-time validation
    class RouteDSL
      @routes = [] of Route
      @namespace_stack = [] of String
      @middleware_stack = [] of Array(Middleware)
      
      # Type-safe route definition with automatic parameter extraction
      macro get(path, controller = nil, action = nil, &block)
        {% if controller && action %}
          add_route("GET", {{path}}, {{controller}}, {{action}})
        {% elsif block %}
          add_route_block("GET", {{path}}) {{block}}
        {% else %}
          {% raise "Route must have either controller#action or a block" %}
        {% end %}
      end
      
      macro post(path, controller = nil, action = nil, &block)
        {% if controller && action %}
          add_route("POST", {{path}}, {{controller}}, {{action}})
        {% elsif block %}
          add_route_block("POST", {{path}}) {{block}}
        {% else %}
          {% raise "Route must have either controller#action or a block" %}
        {% end %}
      end
      
      macro put(path, controller = nil, action = nil, &block)
        {% if controller && action %}
          add_route("PUT", {{path}}, {{controller}}, {{action}})
        {% elsif block %}
          add_route_block("PUT", {{path}}) {{block}}
        {% else %}
          {% raise "Route must have either controller#action or a block" %}
        {% end %}
      end
      
      macro patch(path, controller = nil, action = nil, &block)
        {% if controller && action %}
          add_route("PATCH", {{path}}, {{controller}}, {{action}})
        {% elsif block %}
          add_route_block("PATCH", {{path}}) {{block}}
        {% else %}
          {% raise "Route must have either controller#action or a block" %}
        {% end %}
      end
      
      macro delete(path, controller = nil, action = nil, &block)
        {% if controller && action %}
          add_route("DELETE", {{path}}, {{controller}}, {{action}})
        {% elsif block %}
          add_route_block("DELETE", {{path}}) {{block}}
        {% else %}
          {% raise "Route must have either controller#action or a block" %}
        {% end %}
      end
      
      # RESTful resource routes with automatic naming
      macro resources(name, *, only = nil, except = nil, &block)
        {% 
          resource_name = name.id.stringify
          controller_name = resource_name.camelcase + "Controller"
          
          actions = [:index, :show, :new, :create, :edit, :update, :destroy]
          
          if only
            actions = only
          elsif except
            actions = actions.reject { |a| except.includes?(a) }
          end
        %}
        
        {% for action in actions %}
          {% if action == :index %}
            get "/{{name.id}}", {{controller_name.id}}, :index
          {% elsif action == :show %}
            get "/{{name.id}}/:id", {{controller_name.id}}, :show
          {% elsif action == :new %}
            get "/{{name.id}}/new", {{controller_name.id}}, :new
          {% elsif action == :create %}
            post "/{{name.id}}", {{controller_name.id}}, :create
          {% elsif action == :edit %}
            get "/{{name.id}}/:id/edit", {{controller_name.id}}, :edit
          {% elsif action == :update %}
            put "/{{name.id}}/:id", {{controller_name.id}}, :update
            patch "/{{name.id}}/:id", {{controller_name.id}}, :update
          {% elsif action == :destroy %}
            delete "/{{name.id}}/:id", {{controller_name.id}}, :destroy
          {% end %}
        {% end %}
        
        {% if block %}
          namespace "/{{name.id}}" do
            {{block.body}}
          end
        {% end %}
      end
      
      # Namespace support with middleware
      def namespace(prefix : String, &block)
        @namespace_stack.push(prefix)
        @middleware_stack.push([] of Middleware)
        yield
        @middleware_stack.pop
        @namespace_stack.pop
      end
      
      # Add middleware to current namespace
      def use(middleware : Middleware)
        if stack = @middleware_stack.last?
          stack << middleware
        end
      end
      
      # Member routes (operate on single resource)
      macro member(&block)
        namespace "/:id" do
          {{block.body}}
        end
      end
      
      # Collection routes (operate on collection)
      macro collection(&block)
        {{block.body}}
      end
      
      private def add_route(method : String, path : String, controller : Controller.class, action : Symbol, name : String?)
        full_path = build_full_path(path)
        middleware = current_middleware
        
        route = Route.new(
          method: method,
          path: full_path,
          controller: controller,
          action: action,
          name: name,
          middleware: middleware
        )
        
        @routes << route
        
        # Generate type-safe path helper if name is provided
        if name
          define_path_helper(name, route)
        end
      end
      
      private def add_route_block(method : String, path : String, name : String?, &block : HTTP::Context ->)
        full_path = build_full_path(path)
        middleware = current_middleware
        
        route = BlockRoute.new(
          method: method,
          path: full_path,
          handler: block,
          name: name,
          middleware: middleware
        )
        
        @routes << route
        
        if name
          define_path_helper(name, route)
        end
      end
      
      private def build_full_path(path : String) : String
        parts = @namespace_stack + [path]
        parts.map(&.strip("/")).reject(&.empty?).join("/").prepend("/")
      end
      
      private def current_middleware : Array(Middleware)
        @middleware_stack.flatten
      end
      
      # Generate type-safe path helpers
      private macro define_path_helper(name, route)
        # Extract parameter names from path
        {% 
          params = [] of String
          route.path.scan(/:(\w+)/).each do |match|
            params << match[1]
          end
        %}
        
        # Define method with typed parameters
        def {{name.id + "_path"}}(
          {% for param in params %}
            {{param.id}} : String | Int32 | Int64,
          {% end %}
          **query_params
        ) : String
          path = {{route.path}}
          
          {% for param in params %}
            path = path.gsub(":{{param.id}}", {{param.id}}.to_s)
          {% end %}
          
          unless query_params.empty?
            query = ::HTTP::Params.build do |form|
              query_params.each do |key, value|
                form.add(key.to_s, value.to_s)
              end
            end
            path += "?" + query
          end
          
          path
        end
        
        # Also define URL helper
        def {{name.id + "_url"}}(
          {% for param in params %}
            {{param.id}} : String | Int32 | Int64,
          {% end %}
          **query_params
        ) : String
          "#{request.scheme}://#{request.host}#{{{name.id + "_path"}}(
            {% for param in params %}
              {{param.id}},
            {% end %}
            **query_params
          )}"
        end
      end
      
      def compile : CompiledRoutes
        CompiledRoutes.new(@routes)
      end
    end
  end
end