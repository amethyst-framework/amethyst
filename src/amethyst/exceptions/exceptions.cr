module Amethyst
  module Exceptions

    class AmethystException < Exception; end

    class ControllerException < AmethystException; end

    class HttpException < AmethystException
      getter :status
      getter :msg

      def initialize(@status, @msg)
        super()
      end
    end

    class UnknownContentType < AmethystException

      def initialize(@ext)
        super("Unknown content-type for file extension #{@ext}")
      end
    end

    class UnsupportedHttpMethod < AmethystException

      def initialize(@ext)
        super("Method #{@method} is not supported. Use #{Http::METHODS.join(" ")}")
      end
    end

    require "./http_exceptions"
    require "./controller_exceptions"

  end
end
