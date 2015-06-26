macro create_send
    case method
    {% methods = @type.methods %}
      {% for m in methods %}
        {% if m.args.empty? %}
          when :{{m.name.id}}
          {{m.name.id}}
        {% end %}
      {% end %}
      else raise "Can't call #{method} through send"
    end
end

def send
  create_send
end