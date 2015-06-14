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

	macro view(name, path=__DIR__, *args)
	  class {{name.id.capitalize}}View < Base::View
	    def initialize(
	      {% for arg in args %}
	        @{{arg.id}},
	      {% end %})
	    end
	    ecr_file "{{path.id}}/{{name.id}}.ecr"
	  end
	end

	macro render(view_klass, *args)
	  _view = {{view_klass.id.capitalize}}View.new(
	    {% for arg in args %}
	      {{arg.id}},
	    {% end %})
	  @response.body = _view.render
	end
end
