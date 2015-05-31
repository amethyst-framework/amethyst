# Dependencies
require "http"

# Amethyst dependencies
require "../http"
require "../middleware"
require "../dispatch"
require "../sugar"

# Load files into module namespace
module Amethyst
	module Base
		require "./*"
	end
end