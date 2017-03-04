require "html_builder"

module Amethyst
  module Support
    module ViewHelpers

      def button_to(value="", controller="", action="", method="post", form_class="button_to", button_class="")
        HTML::Builder.new.build do
          form({ method: method, action: "/#{controller}/#{action}", class: form_class }) do
            input({ value: value, type: "submit", class: button_class })
          end
        end
      end

      def check_box(name="", id="", check_class="", values={ checked: "1", unchecked: "0" })
        HTML::Builder.new.build do
          input({ checked: "checked", type: "checkbox", id: id, name: name, value: values[:checked] })
        end
      end

    end
  end
end
