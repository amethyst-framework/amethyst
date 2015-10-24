include Amethyst::Sugar::View

module Amethyst
  module Base
    class View
      include Support::ViewHelpers

      def render
        response = String.new
        to_s(response)
        response.to_s
      end

      macro method_missing(name)
        @controller.@{{name.id}}
      end
    end
  end
end

# class MyView < View
#   context name
#   view_file "view"
# end

# view "My", __DIR__, :name
# name = "Andrew"
# render "My", name
