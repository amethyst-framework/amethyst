# Amethyst [![Build Status](https://travis-ci.org/Codcore/Amethyst.svg)](https://travis-ci.org/Codcore/Amethyst)

Amethyst is a web framework written in [Crystal](https://github.com/manastech/crystal) language. The goals of Amethyst are to be fast as Node.js and comfortable as Rails. Note, Amethyst is at early stage of developing, so a lot of features are missing yet. However, it works :). Why I called my web framework "Amethyst" ? Because Crystal  has a light purple color at GitHub like [amethyst gemstone](http://en.wikipedia.org/wiki/Amethyst).

Latest version - [0.0.7]()
For now, next things are implemented:
- class-based controllers with method-based actions
- middleware support
- simple REST routing
- path, GET and POST params inside actions
- base cookies support
- static files serving
- tools for developers (console logging)

For detailed information, see docs on our [wiki](https://github.com/Codcore/Amethyst/wiki) below:

* [Installation](https://github.com/Codcore/Amethyst/wiki/Installation)
* [Usage](https://github.com/Codcore/Amethyst/wiki/Usage)
* [Controllers](https://github.com/Codcore/Amethyst/wiki/Controllers)
* [Routing](https://github.com/Codcore/Amethyst/wiki/Routing)
* [Middleware](https://github.com/Codcore/Amethyst/wiki/Middleware)
* [Static files](https://github.com/Codcore/Amethyst/wiki/StaticFiles)
* [Applications](https://github.com/Codcore/Amethyst/wiki/Applications)

[Here are some benchmarking results](https://gist.github.com/Codcore/0c7a331b69eed542fb78)

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
