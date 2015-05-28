module Amethyst
	module Core
		require "./application"
		require "./middleware"
		require "./router"
		require "./route"
		require "./base_controller"
		include Middleware
		include Amethyst::Http
	end
end

