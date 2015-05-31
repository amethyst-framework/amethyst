module Amethyst
	module Core
		require "./application"
		require "./middleware"
		require "./router"
		require "./route"
		require "./base_controller"
    require "./sugar"
		require "./config"
		include Middleware
		include Amethyst::Http
    include Sugar
	end
end
include Amethyst::Core
