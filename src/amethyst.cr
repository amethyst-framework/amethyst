require "./amethyst/base"
require "./amethyst/dispatch"
require "./amethyst/http"
require "./amethyst/middleware"
require "./amethyst/session"
require "./amethyst/sugar"
require "./amethyst/support"
require "./amethyst/exceptions"
require "./amethyst/version"
require "base64"
require "secure_random"
require "mime"


# Include all Amethyst modules to global namespace
# But, you can use Amethyst::Modulename approach too
include Amethyst
