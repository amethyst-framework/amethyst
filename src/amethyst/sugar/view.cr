module Amethyst
  module Sugar
    module View
      macro context(*args)
        def initialize(
          {% for arg in args %}
            @{{arg.id}}
          {% end %})
        end
      end

      macro view_file(file, a=__DIR__)
        ecr_file "{{a.id}}/{{file.id}}.ecr"
      end

      macro view(name, path=__DIR__)
        class {{name.id.capitalize}}View < Base::View
          def initialize(controller)
            @controller = controller
            @response = Http::Response.new
          end
          ecr_file "{{path.id}}/{{name.id}}.ecr"
        end
      end

      macro render(view_klass)
        _view = {{view_klass.id.capitalize}}View.new(controller=self)
        @response.body = _view.render
      end

      macro layout(name, path=_DIR_)
        class {{name.id.capitalize}}View < Base::View
          def initialize(controller, view)
            @controller = controller
            @view = view
          end
          ecr_file "{{path.id}}/{{name.id}}.ecr"
        end
      end

      macro render_with_layout(view_klass, layout_klass)
        _view = {{view_klass.id.capitalize}}View.new(controller=self)
        _layout = {{layout_klass.id.capitalize}}View.new(controller=self, view =
                                                         _view.render)
        @response.body = _layout.render
      end
    end
  end
end
