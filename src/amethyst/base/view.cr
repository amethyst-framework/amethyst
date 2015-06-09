require "ecr"
require "ecr/macros"
require "file"

macro view(file, a=__DIR__)
  ecr_file "{{a.id}}/{{file.id}}.ecr"
end

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

# view = MyView.new("Andrew")
# puts view.render