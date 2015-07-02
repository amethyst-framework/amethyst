module Amethyst
  module Exceptions

    class AmethystException < Exception; end

    require "./http_exceptions"
    require "./controller_exceptions"

  end
end
