![Amethyst-logo](http://s019.radikal.ru/i635/1506/28/bac4764b9e03.png)

:warning: Amethyst is currently undergoing a re-write from the ground up. We'll be releasing the public roadmap soon.

Amethyst is a web framework written in the [Crystal](https://github.com/manastech/crystal) language. The goals of Amethyst are to be extremely fast and to provide agility in application development, much like Rails. 

Latest version - [0.1.7](https://github.com/amethyst-framework/amethyst/releases/tag/v0.1.7)
Note that Amethyst is at its early stages, so it lacks for whole bunch of things. But you can give a hand with contributing.
* [Roadmap](https://github.com/Codcore/Amethyst/wiki/Roadmap)

For detailed information, see docs on our [wiki](https://github.com/amethyst-framework/amethyst/wiki) below:

* [Installation](https://github.com/amethyst-framework/amethyst/wiki/Installation)
* [Usage](https://github.com/amethyst-framework/amethyst/wiki/Usage)
* [Controllers](https://github.com/amethyst-framework/amethyst/wiki/Controllers)
* [Routing](https://github.com/amethyst-framework/amethyst/wiki/Routing)
* [Middleware](https://github.com/amethyst-framework/amethyst/wiki/Middleware)
* [Static files](https://github.com/amethyst-framework/amethyst/wiki/StaticFiles)
* [Applications](https://github.com/amethyst-framework/amethyst/wiki/Applications)


[Here are some benchmarking results](https://gist.github.com/Codcore/0c7a331b69eed542fb78)

For now, next things are implemented:
* class-based controllers with method-based actions
* views for actions (`*.ecr`)
* filters for action
* middleware support
* simple REST routing
* default routes for controller
* path, GET and POST params inside actions
* basic cookies support
* static files serving
* http logger and timer for developers
* simple environments support
* simple session support

## Example
Here is classic 'Hello World' in Amethyst
```crystal
require "crystal-on-rails/amethyst"

class WorldController < Base::Controller
  actions :hello

  view "hello", "#{__DIR__}/views"
  def hello
    @name = "World"
    respond_to do |format|
      format.html { render "hello" }
    end
  end
end

class HelloWorldApp < Base::App
  routes.draw do
    all "/",      "world#hello"
    get "/hello", "world#hello"
    register WorldController
  end
end

app = Amethyst.new HelloWorldApp
app.serve

# /views/hello.ecr
Hello, <%= name %>
```

Start your application:

```
crystal deps
crystal build src/hello.cr
```

Go to [http://localhost:8080/](http://localhost:8080/).

## Development

Feel free to fork project and make pull-requests.

## Contributing

I would be glad for any help with contributing.

1. Fork it ( https://github.com/amethyst-framework/amethyst/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request


## Contributors

- [Sean Nieuwoudt](https://github.com/SeanNieuwoudt) BDFL
- [Andrew Yaroshuk](https://github.com/Codcore)

