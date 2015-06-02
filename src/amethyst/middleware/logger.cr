require "./middleware"

class Logger < Middleware::Base

  def log_request(request)
    puts "
---[ REQUEST ]-----------------------------------------------------\n
Http method  :  #{request.method}       \n
Path         :  #{request.path}         \n
Query string :  #{request.query_string} \n

Protocol     :  #{request.protocol}     \n
Host         :  #{request.host}         \n
Port         :  #{request.port}         \n
\n
"
  end

  def log_headers(headers)
    puts "---[ HEADERS ]-----------------------------------------------------\n"
    headers.each do |header, value|
      puts "#{header}  :   #{value}"
    end
    puts ""
  end

  def log_response(response)
    puts "---[ RESPONSE ]-----------------------------------------------------\n
          Status        :  #{response.status_code}\n
          Response      :  #{response.body}\n

          "
  end

  def call(request)
    log_request(request)
    log_headers(request.headers)
  end

  def call(request, response)
    log_response(response)
    log_headers(response.headers)
  end
end