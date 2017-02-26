[//]: # #![Amethyst-logo](http://s019.radikal.ru/i635/1506/28/bac4764b9e03.png)
[//]: # [![Pledgie](https://pledgie.com/campaigns/29689.png?skin_name=chrome)](https://pledgie.com/campaigns/29689)
[//]: # [![Build Status](https://travis-ci.org/Codcore/amethyst.svg)](https://travis-ci.org/Codcore/amethyst)  [![Join the chat at https://gitter.im/Codcore/Amethyst](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/Codcore/Amethyst?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Amethyst is a web framework written in the [Crystal](https://github.com/manastech/crystal) language. The goals of Amethyst are to be extremely fast and to provide agility in application development, much like Rails. Why did I call it "Amethyst"? Because Github uses a light purple color for the Crystal language similar to the [amethyst gemstone](http://en.wikipedia.org/wiki/Amethyst).

Latest version - [0.1.7](https://github.com/Codcore/Amethyst/releases/tag/v0.1.7)
Note that Amethyst is at it early stages, so it lacks for whole bunch of things. But you can give a hand with contributing.
* [Roadmap](https://github.com/Codcore/Amethyst/wiki/Roadmap)

[Amethyst examples](https://github.com/Codcore/amethyst-examples)

For detailed information, see docs on our [wiki](https://github.com/Codcore/Amethyst/wiki) below:

* [Installation](https://github.com/Codcore/Amethyst/wiki/Installation)
* [Usage](https://github.com/Codcore/Amethyst/wiki/Usage)
* [Controllers](https://github.com/Codcore/Amethyst/wiki/Controllers)
* [Routing](https://github.com/Codcore/Amethyst/wiki/Routing)
* [Middleware](https://github.com/Codcore/Amethyst/wiki/Middleware)
* [Static files](https://github.com/Codcore/Amethyst/wiki/StaticFiles)
* [Applications](https://github.com/Codcore/Amethyst/wiki/Applications)


[Here are some benchmarking results](https://gist.github.com/Codcore/0c7a331b69eed542fb78)

For now, next things are implemented:
* class-based controllers with method-based actions
* views for actions (*.ecr)
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
require "amethyst"

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

app = HelloWorldApp.new
app.serve

# /views/hello.ecr
Hello, <%= name %>
```

## Using amethyst-bin to quickly generate your application

[amethyst-bin](https://github.com/Sdogruyol/amethyst-bin) is an executable shell script to help you
quickly generate your Amethyst application.

It handles installing the base dependencies, views / controllers folder generation and main application file generation.

```
curl https://raw.githubusercontent.com/Sdogruyol/amethyst-bin/master/amethyst > amethyst && chmod +x amethyst
./amethyst sample
```

Voila! Your app is ready now you can run it

```cd sample && crystal run src/sample.cr```

## Development

Feel free to fork project and make pull-requests.


## Contributing

I would be glad for any help with contributing.

1. Fork it ( https://github.com/Codcore/amethyst/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request


## Contributors

- [Andrew Yaroshuk](https://github.com/Codcore) Codcore - creator, maintainer

[//] # ## Support
[//] # Amethyst is not a commercial project,it is developed on pure enthusiasm, so if you want to support Amethyst developing, you can help with donating.

[//] # [![Pledgie](https://pledgie.com/campaigns/29689.png?skin_name=chrome)](https://pledgie.com/campaigns/29689)
