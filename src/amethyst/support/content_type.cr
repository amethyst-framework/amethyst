module ContentTypeHelper

  # Returns 'Content-type' header as string
	def content_type : String
    headers["Content-type"]? ? headers["Content-type"].split(";")[0] : ""
  end
  
  # Sets 'Content-type' header as string
  def content_type=(ctype : String)
    headers["Content-type"] = ctype
  end

  # Sets 'Content-type' header from file extension: ctype_ext ".jpg"
  def ctype_ext=(ext : String)
    unless ctype = Mime.from_ext(ext)
      raise Exceptions::UnknowContentType.new(ctype)
    else
      content_type = ctype
    end
  end

  def content_type?(ctype : String)
    matches = false
    matches = true if ctype == content_type
    matches
  end
end