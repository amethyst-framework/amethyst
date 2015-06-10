module Amethyst
	module Exceptions

    class AmethystException < Exceptions
    end

    class ControllerException < BaseException
    end

    class ActionNotFound < ControllerException

      def initialize(action, controller)
        super("Action #{action} not found in controller #{controller }")
      end
    end
    
  end
end