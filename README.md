# Amethyst [![Build Status](https://travis-ci.org/Codcore/Amethyst.svg)](https://travis-ci.org/Codcore/Amethyst)

Amethyst is a web framework written in [Crystal](https://github.com/manastech/crystal) language. The goals of Amethyst are to be fast and user-friendly as Rails. Note, Amethyst is at early stage of developing, so a lot of features are missing yet. However, it works :). Why I called my web framework "Amethyst" ? Because Crystal  has a light purple color at GitHub like [amethyst gemstone](http://en.wikipedia.org/wiki/Amethyst).

For now, next things are implemented:
- class-based controllers with actions
- middleware support
- simple routing

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
          <a href='/bye'>Visit <b>bye</b> action</a>"
  end

  def bye
    html "<p>Bye!We hope you will come back</p>"
  end
end
```
Controllers describe actions as a methods. Actions have direct access to request and response objects, and other helpers, such as a ```html``` .Code ```actions :hello, :bye``` lets app to know which methods of your contoller are actions, and which aren't.

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
```

#Routing

Amethyst has Rails-like approach to describe routes. For now, only ```get()``` supported. 
It consists of path and string ```controller_name#action_name```

```crystal 
Base::App.routes.draw do |routes|
  # maps GET "/" to "hello" action of IndexController
  get "/",    "index#hello"
  # maps GET "/bye" to "bye" action of IndexController
  get "/bye", "index#bye"
  post "/post", "index#bye" # you can use GET, POST, PUT, DELETE
  all "/bye-all", "index#bye" # resoonds to all HTTP methods
end
```

Note, ```/bye``` and ```/bye/``` work slightly different. First matches ```/bye, /bye/, /bye_something```, second is "strict",
and matches only ```/bye``` and ```/bye/```. Both not matches ```/bye/something```.

You can specify params to be captured:
```crystal 
get "/users/:id", "users#show" #(params doesn't work yet)
```

After you defined a controller, you have to register it in app with ```app.routes.register(NameController)``` where ```NameController```(CamelCase) is the classname of your controller:
```crystal
Base::App.routes.register(IndexController)
```
# Application creating

```crystal
# Middleware registering
Base::App.use TimeMiddleware
app = Base::App.new
```
You can set a port and app name (defaul port is ```8080```, default name is name of file application is in):
```crystal
app.port = 8080
app.name = "example"
```
#Running application
```crystal
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
