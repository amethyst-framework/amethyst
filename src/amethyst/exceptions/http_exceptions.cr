module Amethyst
  module Exceptions
    class HttpException < AmethystException
      getter :status
      getter :msg

      def initialize(@status : Int32, @msg : String)
        super()
      end
    end

    class UnknownContentType < AmethystException

      def initialize(@ext : String)
        super("Unknown content-type for file extension #{@ext}")
      end
    end

    class UnsupportedHttpMethod < AmethystException

      def initialize(@method : String)
        super("Method #{@method} is not supported. Use #{Http::METHODS.join(" ")}")
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

    class HttpMethodNotAllowed < HttpException
      getter :method
      getter :allowed

      @allowed : String

      def initialize(@method : String, allowed : Array(String))
        @allowed = allowed.join(",")
        super(405, "Method #{method} not allowed. Allowed : #{@allowed}")
      end
    end

    class HttpNotImplemented < HttpException
      getter :method

      def initialize(@method : String)
        super(501, "Method #{@method} not implemented")
      end
    end
  end
end
