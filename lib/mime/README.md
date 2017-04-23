# mime

Mimetypes for [Crystal](https://github.com/manastech/crystal).

## Installation

Add it to `Projectfile`

```crystal
deps do
  github "spalger/crystal-mime"
end
```

## Usage

```crystal
require "mime"
```

This simple module maps mime-types and extensions. Read the map using either the `from_ext` or `to_ext` methods.

### `Mime.from_ext(extension)`
Read the mime-type for an extension. Returns tye mime-type as a string, or `nil` if the extension is unknown.

```crystal
require "mime"
Mime.from_ext("jpg") # "image/jpeg"
Mime.from_ext("js")  # "application/javascript"
Mime.from_ext("jssssss")  # nil
```

### `Mime.to_ext(type)`
Read the first extension registered for a mime-type. Returns the extension as a string or `nil` is the mime-type is unknown.

```crystal
require "mime"
Mime.to_ext("image/jpeg") # "jpeg"
Mime.to_ext("application/javascript")  # "js"
```

## Development

Type files are pulled from the [node-mime](https://github.com/broofa/node-mime) project. To update the types.json file run
```sh
make update_types
```

## Contributing

1. Fork it ( https://github.com/spalger/crystal-mime/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [spalger](https://github.com/spalger) Spencer Alger - creator, maintainer
