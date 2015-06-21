include Sugar::View

class View

  def button_to(value="", controller="", action="", method="post")
    html = "
    <form method='#{method}' action='/#{controller}/#{action}' class='button_to'>
      <input value='#{value}' type='submit' />
    </form>"
  end
  
  def render
    response = StringIO.new
    to_s(response)
    response.to_s
  end
end

# class MyView < View
#   context name
#   view_file "view"
# end

# view "My", __DIR__, :name
# name = "Andrew"
# render "My", name