module Amethyst
	module Exceptions

    class AmethystException < Exception
    end

    class ControllerException < AmethystException
    end

    class ActionNotFound < ControllerException

      def initialize(action, controller)
        super("Action '#{action}' not found in controller '#{controller }'")
      end
    end

  end
end