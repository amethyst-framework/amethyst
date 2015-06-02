class LoggingMiddleware < Middleware::Base

  def initialize(@justify=120, @indent=3)
  end

  def display_heading(heading : String)
      heading = "\n\n----[ #{heading.upcase} ]"
      heading = heading.ljust(@justify, '-')
      puts heading
  end

  def display_as_list(hash_object, skip = [] of String, justify=15, indent=@indent, skip_empty_values=true)
    print "\n"
    hash_object.each do |name, value|
      name  = name.to_s
      next if skip.includes? name
      next unless value && skip_empty_values
      indent.times { print " " }
      name = name.capitalize
      name = name.ljust(justify, ' ')
      print name
      print " :  "
      puts value.to_s
    end
  end

  def display_array(array_obj : Array, skip = [] of String, justify=15, indent=@indent, skip_empty_values=true)
    array_obj.each do |item|
      item  = item.to_s
      next if skip.includes? item
      next unless value && skip_empty_values
      indent.times { print " " }
      item = item.ljust(justify, ' ')
      print item
      print "\n"
    end
  end

  def display_string(string : String, level=1, indent=@indent)
    indent     = level*indent
    justify    = @justify - indent
    print "\n"
    indent.times { print " " }
    string = string.ljust(justify, '-')
    print string
  end

  def display_object(obj, heading)
    display_heading heading
    display_as_list obj.log
  end

  def display_subheading(subheading : String, level=1, indent=@indent)
    indent     = level*indent
    justify    = @justify - indent - 2
    print "\n"
    indent.times { print " " }
    subheading = "---- #{subheading.downcase} "
    subheading = subheading.ljust(justify, '-')
    print subheading
  end

  def display_end
    print "\n\n"
    (@justify-2).times {print "-"}
    print "\n"
  end
end