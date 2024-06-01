extends Node

func _ready():
	var server = HttpServer.new()
	server.port = 9090
	server.register_router("/fib", FibonacciRouter.new())
	add_child(server)
	server.start()
