require "../src/amethyst"
include Amethyst::Http

port    = 8080
handler = BaseHandler.new
server  = HTTP::Server.new port, handler
server.listen
