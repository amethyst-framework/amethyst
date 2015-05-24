require "../src/amethyst"

app = Application.new
app.add_middleware(BaseMiddleware.new)
app.add_middleware(BaseMiddleware.new)
app.serve
