require "../src/amethyst"
include Amethyst::Http

app = Amethyst::Application.new
app.serve
