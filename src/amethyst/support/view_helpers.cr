class ViewHelpers

  def button_to(value="", controller="", action="", method="post", form_class="button_to", button_class="")
    html = "
    <form method='#{method}' action='/#{controller}/#{action}' class='#{form_class}'>
      <input value='#{value}' type='submit' class='#{button_class}' />
    </form>"
  end

  def check_box(name="", id="" ,values={checked: "1", unchecked: "0"})
    html = "
    <input name='#{name}' type='hidden' value='#{values[:unchecked]}' />
    <input checked='checked' type='checkbox' id='#{id}' name='#{name}' value='#{values[:checked]}' />"
  end

end