extends Node

func _ready():
	var simulator = Simulator.new()
	add_child(simulator)

	var server = HttpServer.new()
	server.port = 9090
	server.register_router("/fib", FibonacciRouter.new())
	server.register_router("/metrics", SimulatorRouter.new(simulator))
	add_child(server)

	server.start()
