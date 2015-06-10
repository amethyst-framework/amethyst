class Logger 

  include Sugar::Klass
  singleton_INSTANCE

  setter :justify
  setter :symbol
  setter :indent
  setter :name

  def initialize(@justify=120, @indent=3, @symbol='_')
    @app = self
  end

  def log_paragraph(name)
    heading = "\n\n"
    heading += @symbol.to_s*4 
    heading += "/ #{name} \\"
    heading = heading.ljust(@justify+1, @symbol)
    heading += "\n"
    puts heading
  end

  def log_heading(name : String, level=1, indent=@indent)
    indent     = level*indent
    justify    = @justify 
    heading = "\n"
    heading += " "*indent
    heading += @symbol.to_s*4
    heading += " #{name.upcase} "
    heading = heading.ljust(justify, @symbol)
    print heading
  end

  def log_hash(hash_object, skip = [] of String, justify=15, skip_empty_values=true)
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

  def log_array(array_obj : Array, skip = [] of String, justify=15)
    array_obj.each do |item|
      item  = item.to_s
      next if skip.includes? item
      @indent.times { print " " }
      item = item.ljust(justify, ' ')
      print item
      print "\n"
    end
  end

  def log_string(string : String, level=1, indent=@indent)
    indent     = level*indent
    justify    = @justify - indent
    print "\n"
    indent.times { print " " }
    print string
  end

  def log_object(obj, heading)
    log_heading heading
    if obj.responds_to?(:log)
      log_hash obj.log
    else
      log_string "Object #{obj.to_s} has no :log method"
    end
  end

  def log_subheading(name : String, level=1, indent=@indent)
    indent     = level*indent
    justify    = @justify 
    subheading = "\n"
    subheading += " "*indent
    subheading += @symbol.to_s*4
    subheading += " #{name.downcase} "
    subheading = subheading.ljust(justify, @symbol)
    print subheading
  end

  def log_end
    print "\n"
    (@justify-1).times {print @symbol}
    print "\n"
  end
end