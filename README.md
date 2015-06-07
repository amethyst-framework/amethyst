# Amethyst [![Build Status](https://travis-ci.org/Codcore/Amethyst.svg)](https://travis-ci.org/Codcore/Amethyst)

Amethyst is a web framework written in [Crystal](https://github.com/manastech/crystal) language. The goals of Amethyst are to be fast as Node.js and comfortable as Rails. Note, Amethyst is at early stage of developing, so a lot of features are missing yet. However, it works :). Why I called my web framework "Amethyst" ? Because Crystal  has a light purple color at GitHub like [amethyst gemstone](http://en.wikipedia.org/wiki/Amethyst).

For now, next things are implemented:
- class-based controllers with actions
- middleware support
- simple routing
- and some new features in new release that coming soon!

[Here are benchmarking results](https://gist.github.com/Codcore/0c7a331b69eed542fb78)

For details, see docs below.

## Installation

Suggested that you have installed [Crystal](https://github.com/manastech/crystal) 0.7.2. **Code may not work properly with earliers version of 0.7.* branch**
```
git clone https://github.com/Codcore/Amethyst.git
```

Or add it to `Projectfile` of your Crystal project

```crystal
deps do
  github "Codcore/amethyst"
end
```
You can play with example of simple web-application written with Amethyst at ```examples``` directory:
```
crystal examples/simple_application.cr
```
## Usage

If you want to load Amethyst in global namespace to be able not to prepend classes with name of modules they are in (for example, ```Base::Controller```),you can load all modules into global namespace next way:
```crystal
require "amethyst/all"
```
From that moment, you can type ```App.new``` instead of ```Base::App.new```, ```Base::Controller``` instead ```Base::Controller```, etc.)

# Controllers
Amethyst controllers are classes with method-actions. The name of any controller must be like ```NameController```,
and it needs to be inherited from ```Base::Controller```. Here is an example of simple controller:

```crystal
require "../src/amethyst"

class IndexController < Base::Controller
  actions :hello, :bye

  def hello
    html "<p>Hello, you're asked a #{request.method} #{request.path}</p> \n
          <a href='/bye'>Visit <b>bye</b> action</a>
          <img src='/images/amethyst.jpg'>"
  end

  def bye
    text "Bye!We hope you will come back"
  end
end
```
Controllers describe actions as a methods. Actions have direct access to request and response objects, and other helpers, such as a ```html``` .Code ```actions :hello, :bye``` lets app to know which methods of your contoller are actions, and which aren't. Inside a controller, you have acces to ```request``` and ```response``` objects. Request has ```query_parameters```, ```request_parameters``` and ```path_parameters``` hashes. First for GET params, second for POST params and third for parts of path marked with a colon. (For example, path "user/1/" matches route "/users/:id", and "id" will be "1").

#Static files
For now,static files served automatically, just specify the path of your static file relative to the dir your app is running from.

# Middleware
Middleware are implemented as classes. Middleware class inherits from ```Base::Middleware``` (or, just type ```Middleware``` if you prefer ```require amethyst/all```), and should have the ```call``` method.
```crystal
def call(request)
end
```
 Here is an example of middleware that calculates time elapsed between request and response.

```crystal
class TimeLogger < Middleware::Base

  # This one will be called when app gets request. It accepts Http::Request
  def call(request)
    logger   = Base::App.logger
    t_req    = Time.now
    response = @app.call(request) # sends request to next middleware
    t_res    = Time.now
    elapsed  = (t_res - t_req).to_f*1000
    string   = "%.4f ms" % elapsed
    response.body += "<hr>"+string
    response
  end
end
```

#Application
After you wrote your controllers, and maybe, middleware you must to setup your app. It is a good way to describe your app with a class, and then run its instance with ```serve```:

```crystal
class TestApp < Base::App
  # Rails-like approach to describe routes.It consists of path
  # and string "controller_name#action_name"
  # You can specify params to be captured:
  # get "/users/:id", "users#show" (not works yet)
  routes.draw do
    all "/all/:id", "index#hello" # "id" will be available at request.ath_parameters"
    get "/",    "index#hello"
    get "/bye", "index#bye"

    # After you defined a controller, you have to register it in app with
    # app.routes.register(NameController) where NameController is the class name
    # of your controller.
    register IndexController
  end

  # Middleware registering
  use TimeLogger
end

# App creating
app = TestApp.new
app.serve
```

## Development

Feel free to fork project and make pull-requests. Stick to standart project structure and name conventions:

    src/
      amethyst/
        module1/       # module1 files
          class1.cr
          ...
          module1.cr   # loads all module1 files into namespace Amethyst::Module1
        module2/
          class1.cr    # describe class Class1 (module, struct, i.e)
          ...
          module2.cr   # loads all module2 files into namespace Amethyst::Module2
        file_module.cr # module that consists of one file
      amethyst.cr      # requires module1.cr, module2.cr, file_module.cr

    spec/
      module1/
        class1_spec.cr # specs for Module1::Class
        spec_helper.cr # loads main spec_helper
      module2/
        class2_spec.cr
      spec_helper      # loads "amethyst/all"

    examples/          # examples to play with
                       # don't forget to require "..src/amethyst" or "..src/all"



## Contributing

I would be glad for any help with contributing.

1. Fork it ( https://github.com/Codcore/amethyst/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request


## Contributors

- [Andrew Yaroshuk](https://github.com/[your-github-name]) Codcore - creator, maintainer
