extends Node

func _ready():
	var simulator: Simulator = Simulator.new()
	add_child(simulator)

	simulator.add_metric("walk", 0.5, func(v,d): return clamp(v + d * 0.1 * (randf() - 0.5), 0.0, 1.0))

	var server = HttpServer.new()
	server.port = 9090
	server.register_router("/fib", FibonacciRouter.new())
	server.register_router("/metrics", SimulatorRouter.new(simulator))
	add_child(server)

	server.start()
