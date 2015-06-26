include Sugar::View

class View

  def button_to(value="", controller="", action="", method="post", html_class="button_to")
    html = "
    <form method='#{method}' action='/#{controller}/#{action}'>
      <input value='#{value}' type='submit' class='#{html_class}' />
    </form>"
  end

  def render
    response = StringIO.new
    to_s(response)
    response.to_s
  end

  macro method_missing(name)
    @controller.@{{name.id}}
  end
end

# class MyView < View
#   context name
#   view_file "view"
# end

# view "My", __DIR__, :name
# name = "Andrew"
# render "My", name