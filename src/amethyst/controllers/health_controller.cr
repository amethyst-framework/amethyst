require "../controller"

module Amethyst
  class HealthController < Controller
    def check
      health_data = {
        status: "ok",
        timestamp: Time.utc.to_unix,
        version: "1.0.0",
        uptime: Time.monotonic.total_seconds.to_i
      }
      
      json(health_data)
    end
  end
end