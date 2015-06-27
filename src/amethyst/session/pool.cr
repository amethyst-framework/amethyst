
class Pool
  property :pool

  def initialize
    @pool = {} of String => Hash
  end

  def generate_sid(cookie="")
    loop do
      sid = Base64.urlsafe_encode64(SecureRandom.random_bytes(128))
      break sid unless @pool.key? sid
    end
    @pool[sid] = {cookie: cookie.to_s}
    sid
  end

  def get_session(sid)
    if @pool.has_key?(sid.to_s)
      @pool[sid.to_s]
    else
      sid = generate_sid
      @pool[sid]
    end
  end

  def destroy_session(sid)
    if @pool.has_key?(sid.to_s)
      @pool.delete(sid.to_s)
    end
  end

end
