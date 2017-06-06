require "./amethyst/base"
require "./amethyst/dispatch"
require "./amethyst/http"
require "./amethyst/middleware"
require "./amethyst/session"
require "./amethyst/sugar"
require "./amethyst/support"
require "./amethyst/exceptions"
require "./amethyst/generators"
require "./amethyst/version"

require "mime"

# All modules classes and inner modules loads to global namespace
include Amethyst
include Amethyst::Base
include Amethyst::Dispatch
include Amethyst::Http
include Amethyst::Generators
include Amethyst::Middleware
include Amethyst::Session
include Amethyst::Support
include Amethyst::Exceptions
