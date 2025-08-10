# Amethyst Web Framework - All Modules
# Includes all framework modules for convenience

require "./amethyst"

# Include all modules for global namespace convenience
include Amethyst
include Amethyst::Base
include Amethyst::Http
include Amethyst::Middleware
include Amethyst::Exceptions
include Amethyst::Security
include Amethyst::Observability