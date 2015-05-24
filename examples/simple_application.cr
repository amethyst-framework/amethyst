require "../src/amethyst"

app = Application.new
app.add_middleware(Middleware.new)
app.serve
