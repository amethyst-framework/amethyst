# Amethyst [![Build Status](https://travis-ci.org/Codcore/Amethyst.svg)](https://travis-ci.org/Codcore/Amethyst)  [![Join the chat at https://gitter.im/Codcore/Amethyst](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/Codcore/Amethyst?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

![Amethyst-logo](http://s019.radikal.ru/i635/1506/28/bac4764b9e03.png)

Amethyst is a web framework written in [Crystal](https://github.com/manastech/crystal) language. The goals of Amethyst are to be fast like Node.js and provide agility in application development as Rails do. Why I called my web framework "Amethyst"? Because Crystal  has a light purple color at GitHub like [amethyst gemstone](http://en.wikipedia.org/wiki/Amethyst).

Latest version - [0.1](https://github.com/Codcore/Amethyst/releases/tag/v0.1)

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
* views for actions (*.ecr) (with some magic behind the scene done for you)
* middleware support
* simple REST routing
* path, GET and POST params inside actions
* basic cookies support
* static files serving
* http logger and timer for developers
* simple environments support

## Example
Here is classic 'Hello World' in Amethyst
```crystal
require "amethyst"

class WordController < Base::Controller
  actions :hello

  view "hello", "#{__DIR__}/views", name
  def hello
    name = "World"
    respond_to do |format|
      format.html { render "hello", name }
    end
  end
end

class HelloWorldApp < Base::App
  routes.draw do
    all "/",      "word#hello" 
    get "/hello", "word#hello" 
    register WordController
  end
end

app = HelloWorldApp.new
app.serve

# /views/hello.ecr
Hello, <%= @name %>
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

- [Andrew Yaroshuk](https://github.com/Codcore]) Codcore - creator, maintainer
