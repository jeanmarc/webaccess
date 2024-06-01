extends Node

func _ready():
	var webappServer = HttpFileRouter.new("../exports")

	var server = HttpServer.new()
	server.register_router("/fib", FibonacciRouter.new())
	server.register_router("/app", webappServer)
	server.enable_cors(["*"])
	add_child(server)
	server.start()
