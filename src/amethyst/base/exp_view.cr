require "ecr"
require "ecr/macros"
require "file"

macro context(*args)
  def initialize(
    {% for arg in args %}
      @{{arg.id}}
    {% end %})
  end
end

class View

  def render
    response = StringIO.new
    to_s(response)
    response
  end

end

# class MyView < View
#   context name
#   view "view"
# end

macro view(name, path=__DIR__, *args)
  class MyView < View
    def initialize(
      {% for arg in args %}
        @{{arg.id}},
      {% end %})
    end
    ecr_file "{{path.id}}/{{name.id}}.ecr"
  end
end

macro render(view_klass, *args)
  _view = {{view_klass.id}}View.new(
    {% for arg in args %}
      {{arg.id}},
    {% end %})
   response = _view.render
end

view "My", __DIR__, :name

name = "Andrew"

puts render "My", name