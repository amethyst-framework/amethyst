class HttpException < AmethystException
  getter :status
  getter :msg

  def initialize(@status, @msg)
    super()
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