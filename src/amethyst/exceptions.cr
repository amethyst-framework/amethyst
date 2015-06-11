module Amethyst
	module Exceptions

    class AmethystException < Exception

    end

    class ControllerException < AmethystException
    end

    class HttpException < AmethystException
      getter :status
      getter :msg

      def initialize(@status, @msg)
        super()
      end
    end

    class ControllerActionNotFound < ControllerException

      def initialize(action, controller)
        super("Action '#{action}' not found in controller '#{controller }'")
      end
    end

    class HttpNotFound < HttpException

      def initialize
        super(404, "Not found")
      end
    end

    class HttpBadRequest < HttpException

      def initialize
        super(400, "Bad request")
      end
    end

  end
end