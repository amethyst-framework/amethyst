# Dependencies
require "http"
require "ecr"
require "ecr/macros"

# Amethyst dependencies
require "../http"
require "../middleware"
require "../dispatch"
require "../session"
require "../sugar"
require "../support"
require "../exceptions"

# Load files into module namespace
module Amethyst
  module Base
    require "./*"
  end
end
