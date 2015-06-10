module View
	macro context(*args)
	  def initialize(
	    {% for arg in args %}
	      @{{arg.id}}
	    {% end %})
	  end
	end

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
	  @response.body = _view.render
	end
end