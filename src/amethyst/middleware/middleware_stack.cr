class MiddlewareStack

  include Sugar
  singleton_INSTANCE
  
  def initialize()
    @middlewares   = [] of Middleware::Base
  end

  def build_middleware
    app = Dispatch::Router::INSTANCE
    @middlewares.reverse.each do |mdware|
      app = mdware.build(app)
    end
    app
  end

  def use(middleware)
    @middlewares << instantiate middleware
  end
end