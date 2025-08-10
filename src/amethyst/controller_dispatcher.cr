require "./controller"
require "./http/request"
require "./http/response"
require "./controllers/health_controller"
require "./controllers/metrics_controller"

module Amethyst
  # Dispatches controller actions from string names
  class ControllerDispatcher
    @controllers = {} of String => Controller.class
    
    def self.instance
      @@instance ||= new
    end
    
    def initialize
      @controllers = {} of String => Controller.class
    end
    
    def register_controller(name : String, controller_class : Controller.class)
      @controllers[name] = controller_class
    end
    
    def dispatch(controller_name : String, action : String, request : Http::Request, params : Hash(String, String) = {} of String => String) : Http::Response
      controller_class = @controllers[controller_name]?
      
      unless controller_class
        return Http::Response.new(500, "Controller not found: #{controller_name}")
      end
      
      begin
        controller = controller_class.new
        controller.set_request(request)
        controller.set_params(params)
        
        # Dispatch to the correct controller and action
        case controller_name
        when "HealthController"
          health_controller = controller.as(HealthController)
          case action
          when "check"
            health_controller.check
          else
            method_not_found(controller_name, action)
          end
        when "MetricsController"
          metrics_controller = controller.as(MetricsController)
          case action
          when "show"
            metrics_controller.show
          else
            method_not_found(controller_name, action)
          end
        else
          # For user controllers, we'd need a registration system or macro
          Http::Response.new(500, "Custom controller dispatch not implemented yet")
        end
      rescue ex : Exception
        Http::Response.new(500, "Controller error: #{ex.message}")
      end
    end
    
    private def method_not_found(controller_name : String, action : String)
      Http::Response.new(500, "Action '#{action}' not found on controller '#{controller_name}'")
    end
    
    # This would need to be implemented with macros or reflection in a real system
    # For now, we'll use a simple approach
    private def call_controller_action(controller : Controller, action : String) : Http::Response
      # In a real implementation, you'd want proper method dispatch
      # For now, return a simple error
      Http::Response.new(500, "Method dispatch not implemented for action: #{action}")
    end
  end
  
  # Macro to help register controllers
  macro register_controller(name, controller_class)
    ControllerDispatcher.instance.register_controller({{ name }}, {{ controller_class }})
  end
end