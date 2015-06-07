# Dependencies
require "http"

# Amethyst dependencies
require "../http"
require "../middleware"
require "../dispatch"
require "../sugar"
require "../support"

# Load files into module namespace
module Amethyst
	module Base
		require "./*"
	end
end