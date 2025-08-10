require "json"

module Amethyst
  # Automatic OpenAPI/Swagger documentation generator
  module OpenAPI
    class Generator
      @routes : Routing::CompiledRoutes
      @title : String
      @version : String
      @description : String?
      @servers : Array(Server)
      
      def initialize(@routes, @title = "API Documentation", @version = "1.0.0", @description = nil)
        @servers = [] of Server
      end
      
      def add_server(url : String, description : String? = nil)
        @servers << Server.new(url, description)
      end
      
      # Generate full OpenAPI specification
      def generate : String
        spec = {
          openapi: "3.0.3",
          info: generate_info,
          servers: @servers.map(&.to_h),
          paths: generate_paths,
          components: generate_components
        }
        
        spec.to_pretty_json
      end
      
      private def generate_info
        info = {
          title: @title,
          version: @version
        }
        
        info[:description] = @description if @description
        info
      end
      
      private def generate_paths
        paths = {} of String => JSON::Any
        
        @routes.routes.each do |route|
          next unless route.is_a?(Routing::Route)
          
          path_item = paths[route.path]?.try(&.as_h) || {} of String => JSON::Any
          operation = generate_operation(route)
          path_item[route.method.downcase] = JSON.parse(operation.to_json)
          paths[route.path] = JSON.parse(path_item.to_json)
        end
        
        paths
      end
      
      private def generate_operation(route : Routing::Route)
        controller_class = route.controller
        action = route.action
        
        operation = {
          operationId: "#{controller_class.name.split("::").last.underscore.gsub(/_controller$/, "")}_#{action}",
          tags: [controller_class.name.split("::").last.gsub(/Controller$/, "").underscore],
          parameters: generate_parameters(route),
          responses: generate_responses(controller_class, action)
        }
        
        # Extract metadata from controller if available
        if controller_class.has_constant?("OPENAPI_SUMMARY")
          operation[:summary] = controller_class.constant("OPENAPI_SUMMARY")
        end
        
        if controller_class.has_constant?("OPENAPI_DESCRIPTION")
          operation[:description] = controller_class.constant("OPENAPI_DESCRIPTION")
        end
        
        if controller_class.has_constant?("OPENAPI_BODY")
          operation[:requestBody] = generate_request_body(controller_class.constant("OPENAPI_BODY"))
        end
        
        operation
      end
      
      private def generate_parameters(route : Routing::Route)
        parameters = [] of Hash(String, JSON::Any)
        
        # Path parameters
        route.param_names.each do |name|
          parameters << {
            "name" => JSON::Any.new(name),
            "in" => JSON::Any.new("path"),
            "required" => JSON::Any.new(true),
            "schema" => JSON::Any.new({
              "type" => JSON::Any.new("string")
            })
          }
        end
        
        # Add common query parameters based on action
        case route.action
        when :index
          # Pagination parameters
          parameters << {
            "name" => JSON::Any.new("page"),
            "in" => JSON::Any.new("query"),
            "required" => JSON::Any.new(false),
            "schema" => JSON::Any.new({
              "type" => JSON::Any.new("integer"),
              "minimum" => JSON::Any.new(1),
              "default" => JSON::Any.new(1)
            })
          }
          
          parameters << {
            "name" => JSON::Any.new("per_page"),
            "in" => JSON::Any.new("query"),
            "required" => JSON::Any.new(false),
            "schema" => JSON::Any.new({
              "type" => JSON::Any.new("integer"),
              "minimum" => JSON::Any.new(1),
              "maximum" => JSON::Any.new(100),
              "default" => JSON::Any.new(20)
            })
          }
        end
        
        parameters
      end
      
      private def generate_responses(controller_class, action)
        responses = {} of String => JSON::Any
        
        # Default responses based on action
        case action
        when :index
          responses["200"] = JSON.parse({
            description: "Successful response",
            content: {
              "application/json" => {
                schema: {
                  type: "array",
                  items: {
                    type: "object"
                  }
                }
              }
            }
          }.to_json)
        when :show
          responses["200"] = JSON.parse({
            description: "Successful response",
            content: {
              "application/json" => {
                schema: {
                  type: "object"
                }
              }
            }
          }.to_json)
          responses["404"] = JSON.parse({
            description: "Resource not found"
          }.to_json)
        when :create
          responses["201"] = JSON.parse({
            description: "Resource created successfully",
            content: {
              "application/json" => {
                schema: {
                  type: "object"
                }
              }
            }
          }.to_json)
          responses["422"] = JSON.parse({
            description: "Validation error"
          }.to_json)
        when :update
          responses["200"] = JSON.parse({
            description: "Resource updated successfully"
          }.to_json)
          responses["404"] = JSON.parse({
            description: "Resource not found"
          }.to_json)
          responses["422"] = JSON.parse({
            description: "Validation error"
          }.to_json)
        when :destroy
          responses["204"] = JSON.parse({
            description: "Resource deleted successfully"
          }.to_json)
          responses["404"] = JSON.parse({
            description: "Resource not found"
          }.to_json)
        end
        
        # Add custom responses if defined
        if controller_class.has_constant?("OPENAPI_RESPONSES")
          custom_responses = controller_class.constant("OPENAPI_RESPONSES")
          # Process custom responses...
        end
        
        # Always add common error responses
        responses["401"] = JSON.parse({
          description: "Unauthorized"
        }.to_json)
        
        responses["500"] = JSON.parse({
          description: "Internal server error"
        }.to_json)
        
        responses
      end
      
      private def generate_request_body(body_config)
        {
          required: body_config[:required],
          content: {
            "application/json" => {
              schema: generate_schema_for_type(body_config[:type])
            }
          }
        }
      end
      
      private def generate_schema_for_type(type)
        # This would be expanded to handle various Crystal types
        # For now, return a generic object schema
        {
          type: "object"
        }
      end
      
      private def generate_components
        {
          securitySchemes: {
            bearerAuth: {
              type: "http",
              scheme: "bearer",
              bearerFormat: "JWT"
            },
            apiKey: {
              type: "apiKey",
              in: "header",
              name: "X-API-Key"
            }
          }
        }
      end
      
      struct Server
        getter url : String
        getter description : String?
        
        def initialize(@url, @description = nil)
        end
        
        def to_h
          h = {"url" => @url}
          h["description"] = @description if @description
          h
        end
      end
    end
    
    # Swagger UI middleware
    class SwaggerUI
      SWAGGER_UI_VERSION = "4.15.5"
      
      def self.call(context : HTTP::Context)
        context.response.content_type = "text/html"
        context.response.body = generate_html(context.request.path.rstrip("/swagger"))
      end
      
      private def self.generate_html(base_path : String)
        <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>API Documentation</title>
          <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@#{SWAGGER_UI_VERSION}/swagger-ui.css">
          <style>
            body { margin: 0; padding: 0; }
            .swagger-ui .topbar { display: none; }
          </style>
        </head>
        <body>
          <div id="swagger-ui"></div>
          <script src="https://unpkg.com/swagger-ui-dist@#{SWAGGER_UI_VERSION}/swagger-ui-bundle.js"></script>
          <script src="https://unpkg.com/swagger-ui-dist@#{SWAGGER_UI_VERSION}/swagger-ui-standalone-preset.js"></script>
          <script>
            window.onload = function() {
              SwaggerUIBundle({
                url: "#{base_path}/swagger.json",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                  SwaggerUIBundle.presets.apis,
                  SwaggerUIStandalonePreset
                ],
                plugins: [
                  SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout"
              });
            };
          </script>
        </body>
        </html>
        HTML
      end
    end
  end
end