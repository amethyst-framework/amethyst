module Amethyst
  module Exceptions
    class ControllerException < AmethystException; end
    
    class ControllerActionNotFound < ControllerException
      getter :action
      getter :controller

      def initialize(action, controller)
        super("Action '#{action}' not found in controller '#{controller }'")
      end
    end
  end
end
