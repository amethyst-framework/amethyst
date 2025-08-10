require "../controller"
require "../middleware/metrics_middleware"

module Amethyst
  class MetricsController < Controller
    def show
      # Get real metrics from the middleware
      metrics = Middleware::MetricsMiddleware.get_metrics
      
      Http::Response.new(200, metrics, ::HTTP::Headers{"Content-Type" => "text/plain"})
    end
  end
end