# Modern Amethyst Base Module
# Provides core application functionality

require "http"
require "../http"
require "../middleware"
require "../routing/**"
require "../websocket/**"
require "../sse/**"
require "../security/**"
require "../observability/**"

require "./config"
require "./logger"
require "./app"
require "./connection_pool"
require "./optimized_app"

module Amethyst
  module Base
    # Re-export modern app classes for backward compatibility
    alias Controller = ::Amethyst::Controller
  end
end