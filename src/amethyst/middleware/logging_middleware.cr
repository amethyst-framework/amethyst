class LoggingMiddleware < Middleware::Base

  setter :justify
  setter :symbol
  setter :indent
  setter :name

  def initialize(@justify=120, @indent=3, @symbol='_')
    @name=self
  end

  def display_name
    heading = "\n\n"
    heading += @symbol.to_s*4 
    heading += "/ #{@name} \\"
    heading = heading.ljust(@justify+1, @symbol)
    heading += "\n"
    puts heading
  end

  def display_heading(name : String, level=1, indent=@indent)
    indent     = level*indent
    justify    = @justify 
    heading = "\n"
    heading += " "*indent
    heading += @symbol.to_s*4
    heading += " #{name.upcase} "
    heading = heading.ljust(justify, @symbol)
    print heading
  end

  def display_as_list(hash_object, skip = [] of String, justify=15, skip_empty_values=true)
    print "\n"
    hash_object.each do |name, value|
      value = false if value.to_s.empty?
      name  = name.to_s
      next if skip.includes? name
      next unless value && skip_empty_values 
      @indent.times { print " " }
      name = name.capitalize
      name = name.ljust(justify, ' ')
      print name
      print " :  "
      puts value.to_s
    end
  end

  def display_array(array_obj : Array, skip = [] of String, justify=15)
    array_obj.each do |item|
      item  = item.to_s
      next if skip.includes? item
      @indent.times { print " " }
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
    #string = string.ljust(justify, @symbol) 
    print string
  end

  def display_object(obj, heading)
    display_heading heading
    display_as_list obj.log
  end

  def display_subheading(name : String, level=1, indent=@indent)
    indent     = level*indent
    justify    = @justify 
    subheading = "\n"
    subheading += " "*indent
    subheading += @symbol.to_s*4
    subheading += " #{name.downcase} "
    subheading = subheading.ljust(justify, @symbol)
    print subheading
  end

  def display_end
    print "\n"
    (@justify).times {print @symbol}
    print "\n"
  end
end