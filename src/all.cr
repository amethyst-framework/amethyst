require "./amethyst/base"
require "./amethyst/dispatch"
require "./amethyst/http"
require "./amethyst/middleware"
require "./amethyst/sugar"
require "./amethyst/support"
require "./amethyst/version"

# All modules classes and inner modules loads to global namespace
include Amethyst
include Amethyst::Base
include Amethyst::Dispatch
include Amethyst::Http
include Amethyst::Middleware
include Amethyst::Support