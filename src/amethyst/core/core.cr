module Amethyst
	module Core
		require "./application"
		require "./middleware"
		include Middleware
		include Amethyst::Http
	end
end

