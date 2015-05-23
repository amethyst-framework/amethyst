# Amethyst [![Build Status](https://travis-ci.org/Codcore/Amethyst.svg)](https://travis-ci.org/Codcore/Amethyst)

Amethyst is a experimental web-framework written in [Crystal](https://github.com/manastech/crystal) language. Project currently is under construction. Partially inspired by [Moonshine](https://github.com/dhruvrajvanshi/Moonshine)

## Installation

Add it to `Projectfile`

```crystal
deps do
  github "Codcore/amethyst"
end
```

## Usage

```crystal
require "amethyst"
include Amethyst::Http

app = Amethyst::Application.new
app.port = 8000
app.serve       #simple Amethyst application. No routing for now
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
