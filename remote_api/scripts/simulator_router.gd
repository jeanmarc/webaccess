extends HttpRouter
class_name SimulatorRouter

var metrics_simulator: Simulator

func _init(sim: Simulator):
	metrics_simulator = sim

func handle_get(request, response):
	var answer = metrics_simulator.metrics_data()
	response.send(200, answer)
