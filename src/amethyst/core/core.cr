module Amethyst
	module Core
		require "./application"
		require "./middleware"
		require "./router"
		require "./route"
		include Middleware
		include Amethyst::Http
	end
end

