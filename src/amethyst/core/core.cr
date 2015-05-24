include Amethyst::Http

module Amethyst
	module Core
		require "./application"
		require "./middleware"
		include Middleware
	end
end

