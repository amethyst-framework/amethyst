# Amethyst [![Build Status](https://travis-ci.org/Codcore/Amethyst.svg)](https://travis-ci.org/Codcore/Amethyst)

Amethyst is a experimental web-framework written in [Crystal](https://github.com/manastech/crystal) language. Project currently is under construction. You can 
find an example of simple web-application written with Amethyst below. Note, Amethyst is in very early stage, so a lot of base features are missing yet. However, it
works :). Would be glad for any help with contributing.

## Installation

Add it to `Projectfile`

```crystal
deps do
  github "Codcore/amethyst"
end
```

## Usage

```crystal
# If you want to load Amethyst in global namespace to be able not to prepend
# classes with name of modules they are in (for example, Core::BaseController),
# you can load all modules into global namespace with next code:
# require "amethyst/all" (i.e. Application.new instead of Core::Application.new, etc.)

require "../src/amethyst"

# Controller class. The name of controller must be "NameController",
# and it needs to be inherited from BaseController
class IndexController < Core::BaseController

  # Controller action. It gets request of Http::Requst as an argument.
  # For now, each controller should return Http::Response by itself.
  def hello(request)
    puts "hello"
    Http::Response.new(200, "Hello!Welcome to Amethyst!")
  end

  def bye(request)
    puts "bye"
    Http::Response.new(200, "Bye!Amethyst will miss you...")
  end

  # Method "actions" must be provided by each controller of your application.
  # It lets app to know which methods of your contoller are actions.
  # The synopsys is add :action_name
  def actions
    add :hello
    add :bye
  end
end

# Middleware is implemented as classes. Middleware class inherits from
# Core::Middleware::BaseMiddleware (or, just type "BaseMiddleware" if you  are
# using "amethyst/all"), and should have the "call" method.
# Actually, there are two call methods with different signatures.
class TimeMiddleware < Core::Middleware::BaseMiddleware

  # All istance variables have to be initialized here to use them in call methods
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
    @t_res = Time.now
    response.body += "\n Time elapsed: #{(@t_res-@t_req)} seconds"
  end

end

# Application creating
app = Core::Application.new
# Middleware registering
app.use(TimeMiddleware.new)

# Rails-like approach to describe routes. For now, only get() supported.
# It consists of path and string "controller_name#action_name"
# You can specify params to be captured:
# get "/users/:id", "users#show" (not works yet)
app.routes.draw do |routes|
  get "/index",     "index#hello"
  get "/index/bye", "index#bye"
end

# After you defined a controller, you have to register it in app with
# app.routes.register(NameController) where NameController is the class name
# of your controller.
app.routes.register(IndexController)
# Standart port which application will be served on, is 8080
# You can set port with:
# app.port = 3000
app.serve
```


## Development

Feel free to fork project and make pull-requests. Stick to standart project structure and name conventions:

    src/
      amethyst/
        module1/       #module1 files
          class1.cr
          ...
          module1.cr   #loads all module1 files into namespace Amethyst::Module1
        module2/
          class1.cr    #describe class Class1 (module, struct, i.e)
          ...
          module2.cr   #loads all module2 files into namespace Amethyst::Module2
        file_module.cr #module that consists of one file
      amethyst.cr      #requires module1.cr, module2.cr, file_module.cr

    spec/
      module1/
        class1_spec.cr #specs for Module1::Class
      module2/
        class2_spec.cr
      spec_helper      #loads amethyst.cr

    examples/          #examples to play with
                       #don't forget to require "..src/amethyst"



## Contributing

1. Fork it ( https://github.com/Codcore/amethyst/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [Codcore](https://github.com/[your-github-name]) codcore - creator, maintainer
