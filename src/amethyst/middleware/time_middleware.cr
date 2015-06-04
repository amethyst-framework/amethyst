require "./middleware"
class TimeLogger < Middleware::Base

  # This one will be called when app gets request. It accepts Http::Request
  def call(request)
    logger = Base::App.logger
    t_req = Time.now
    response = @app.call(request)
    t_res  = Time.now
    elapsed = (t_res - t_req).to_f*1000
    string  = "%.4f ms" % elapsed
    logger.display_name
    logger.display_as_list ({ "Time elapsed" => string })
    response
  end
end