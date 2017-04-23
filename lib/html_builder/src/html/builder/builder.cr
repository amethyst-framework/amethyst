require "html"

# Defines a DSL for creating HTML.
#
# Usage:
#
# ```
# require "html_builder"
#
# html = HTML.build do
#   a(href: "http://crystal-lang.org") do
#     text "crystal is awesome"
#   end
# end
#
# puts html # => %(<a href="http://crystal-lang.org">crystal is awesome</a>)
# ```
struct HTML::Builder
  # Creates a new HTML::Builder, yields with with `with ... yield`
  # and then returns the resulting string.
  def self.build
    new.build do |builder|
      with builder yield builder
    end
  end

  def initialize
    @str = IO::Memory.new
  end

  def build
    with self yield self
    @str.to_s
  end

  # Renders `HTML` doctype tag.
  #
  # ```
  # HTML::Builder.new.build { doctype } # => <doctype/>
  # ```
  def doctype
    @str << "<!DOCTYPE html>"
  end

  # Renders `BR` html tag.
  #
  # ```
  # HTML::Builder.new.build { br } # => <br/>
  # ```
  def br
    @str << "<br/>"
  end

  # Renders `HR` html tag.
  #
  # ```
  # HTML::Builder.new.build { hr } # => <hr/>
  # ```
  def hr
    @str << "<hr/>"
  end

  # Renders escaped text in html tag.
  #
  # ```
  # HTML::Builder.new.build { text "crystal is awesome" }
  # # => crystal is awesome
  # ```
  def text(text)
    @str << HTML.escape(text)
  end

  # Renders the provided html string.
  #
  # ```
  # HTML::Builder.new.build { html "<p>crystal is awesome</p>" }
  # # => <>crystal is awesome</p>
  # ```
  def html(html)
    @str << html
  end

  # Renders the provided html tag with any options.
  #
  # ```
  # HTML::Builder.new.build do
  #   tag("section", {class: "crystal"}) { text "crystal is awesome" }
  # end
  # # => <section class="crystal">crystal is awesome</section>
  # ```
  def tag(name, attrs)
    @str << "<#{name}"
    append_attributes_string(attrs)
    @str << ">"
    with self yield self
    @str << "</#{name}>"
  end

  def tag(name, **attrs)
    @str << "<#{name}"
    append_attributes_string(**attrs)
    @str << ">"
    with self yield self
    @str << "</#{name}>"
  end

  {% for tag in %w(a b body button div em fieldset h1 h2 h3 head html i label li ol option p s script select span strong table tbody td textarea thead th title tr u ul form footer header article aside bdi details dialog figcaption figure main mark menuitem meter nav progress rp rt ruby section summary time wbr) %}
    # Renders `{{tag.id.upcase}}` html tag with any options.
    #
    # ```
    # HTML::Builder.new.build do
    #   {{tag.id}}({:class => "crystal" }) { text "crystal is awesome" }
    # end
    # # => <{{tag.id}} class="crystal">crystal is awesome</{{tag.id}}>
    # ```
    def {{tag.id}}(attrs)
      @str << "<{{tag.id}}"
      append_attributes_string(attrs)
      @str << ">"
      with self yield self
      @str << "</{{tag.id}}>"
    end

    # Renders `{{tag.id.upcase}}` html tag with any options.
    #
    # ```
    # HTML::Builder.new.build do
    #   {{tag.id}}(class: "crystal") { text "crystal is awesome" }
    # end
    # # => <{{tag.id}} class="crystal">crystal is awesome</{{tag.id}}>
    # ```
    def {{tag.id}}(**attrs)
      @str << "<{{tag.id}}"
      append_attributes_string(**attrs)
      @str << ">"
      with self yield self
      @str << "</{{tag.id}}>"
    end
  {% end %}

  {% for tag in %w(link input img) %}
    # Renders `{{tag.id.upcase}}` html tag with any options.
    #
    # ```
    # HTML::Builder.new.build do
    #   {{tag.id}}({:class => "crystal")
    # end
    # # => <{{tag.id}} class="crystal">
    # ```
    def {{tag.id}}(attrs)
      @str << "<{{tag.id}}"
      append_attributes_string(attrs)
      @str << ">"
    end

    # Renders `{{tag.id.upcase}}` html tag with any options.
    #
    # ```
    # HTML::Builder.new.build do
    #   {{tag.id}}(class: "crystal")
    # end
    # # => <{{tag.id}} class="crystal">
    # ```
    def {{tag.id}}(**attrs)
      @str << "<{{tag.id}}"
      append_attributes_string(**attrs)
      @str << ">"
    end
  {% end %}

  private def append_attributes_string(attrs)
    attrs.try &.each do |name, value|
      @str << " "
      @str << name
      @str << %(=")
      HTML.escape(value, @str)
      @str << %(")
    end
  end

  private def append_attributes_string(**attrs)
    attrs.each do |name, value|
      @str << " "
      @str << name
      @str << %(=")
      HTML.escape(value, @str)
      @str << %(")
    end
  end
end

module HTML
  # Convenience method which invokes `HTML::Builder#build`.
  def self.build
    HTML::Builder.build do |builder|
      with builder yield builder
    end
  end
end
