# Modern Amethyst Framework - Type-safe, Zero Boilerplate Web Framework for Crystal
#
# Features:
# - Type-safe routing with compile-time validation
# - Automatic parameter extraction and validation  
# - Zero boilerplate controller actions
# - Automatic OpenAPI/Swagger documentation
# - Built-in development tools (hot reload, rich error pages)
# - Content negotiation
# - Modern middleware as functions
# - Smart conventions with escape hatches

require "json"
require "log"
require "http"

# Core modules
require "./amethyst/params"
require "./amethyst/controller"
require "./amethyst/routing/*"
require "./amethyst/openapi"
require "./amethyst/dev_tools"
require "./amethyst/application"

module Amethyst
  extend self
  
  # Version defined in version.cr
  
  # Quick application creation
  def new(&block)
    app = Application.new
    with app yield
    app
  end
  
  # Create application with block
  def application(&block)
    new(&block)
  end
end

# Export main classes for convenience
alias AmethystApp = Amethyst::Application
alias AmethystController = Amethyst::Controller