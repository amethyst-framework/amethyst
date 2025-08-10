# Amethyst Web Framework
# Modern, user-friendly web framework for Crystal

require "./amethyst/version"
require "./amethyst/exceptions"
require "./amethyst/http"
require "./amethyst/middleware"
require "./amethyst/routing/**"
require "./amethyst/base"
require "./amethyst/websocket/**"
require "./amethyst/sse/**"
require "./amethyst/security/**"
require "./amethyst/observability/**"
require "./amethyst/controller"
require "./amethyst/params"
require "./amethyst/openapi"
require "./amethyst/dev_tools"
require "./amethyst/config/**"
require "./amethyst/application"

# Core dependencies
require "base64"
require "random/secure"
require "json"
require "http"
require "log"

module Amethyst
  extend self
  
  # Create a new modern application with builder pattern
  def new(environment : String = "development")
    Application.new(environment)
  end
  
  # Create application with fluent DSL
  def application(environment : String = "development", &block : Application -> Nil)
    app = Application.new(environment)
    block.call(app)
    app
  end
  
  # Backwards compatibility - create legacy app
  def legacy_app(app_class = nil, app_path = __FILE__)
    if app_class
      app_class.new(app_path, app_class.name)
    else
      Base::App.new(app_path)
    end
  end
end

# Convenience aliases
alias AmethystApp = Amethyst::Application
alias AmethystController = Amethyst::Controller

# Quick DSL for simple applications
def amethyst(environment : String = "development", &block : Amethyst::Application -> Nil)
  Amethyst.application(environment, &block)
end