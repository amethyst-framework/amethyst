# If you want to load Amethyst in global namespace to be able not to prepend
# classes with name of modules they are in (for example, Core::BaseController),
# you can load all modules into global namespace with next code:
# require "amethyst/all" (i.e. App.new instead of Core::App.new, etc.)

require "../src/amethyst"

# Controller class. The name of controller must be "NameController",
# and it needs to be inherited from BaseController
class IndexController < Base::Controller

	# Controller action. It gets request of Http::Requst as an argument.
	# For now, each controller should return Http::Response by itself.
	def hello
  	html "<p>Hello, you're asked a #{request.method} #{request.path}</p> \n
          <a href='/bye'>Visit <b>bye</b> action</a>"
	end

	def bye
    html "<p>Bye!We hope you will come back</p>"
	end

	# Method "actions" must be provided by each controller of your application.
	# It lets app to know which methods of your contoller are actions.
	# The synopsys is add :action_name
	def actions
		add :hello
		add :bye
	end
end

# Middleware are implemented as classes. Middleware class inherits from
# Core::Middleware::BaseMiddleware (or, just type "BaseMiddleware" if you  are
# using "amethyst/all"), and should have the "call" method.
# Actually, there are two call methods with different signatures.
class TimeMiddleware < Base::Middleware

  # All instance variables have to be initialized here to use them in call methods
  def initialize
    @t_req = Time.new 
    @t_res = Time.new
  end

  # This one will be called when app gets request. It accepts Http::Request
  def call(request)
    @t_req = Time.now
  end

  # This one will be called when response returned from controller. It accepts both
  # Http::Request and Http::Response
	def call(request, response)
    @t_res  = Time.now
    elapsed = (@t_res - @t_req).to_f*1000
    response.body +=  "<hr> Time elapsed:  %.4f ms" % elapsed
  end

end

# App creating
app = Base::App.new
# Middleware registering
app.use(TimeMiddleware.new)

# Rails-like approach to describe routes. For now, only get() supported.
# It consists of path and string "controller_name#action_name"
# You can specify params to be captured:
# get "/users/:id", "users#show" (not works yet)
app.routes.draw do
  all "/all", "index#hello" 
	get "/", 	  "index#hello"
	get "/bye", "index#bye"
end

# After you defined a controller, you have to register it in app with
# app.routes.register(NameController) where NameController is the class name
# of your controller.
app.routes.register(IndexController)
app.serve