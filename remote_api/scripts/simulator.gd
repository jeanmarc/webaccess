extends Node
class_name Simulator

var metrics={
	"runtime": { "value" : 0.0, "lambda": func(val, delta): return val + delta},
	"random": { "value" : 0.0, "lambda": func(val, delta): return randf()}
}

func _ready():
	pass

func _process(delta):
	for metric in metrics:
		metrics[metric]["value"] = metrics[metric]["lambda"].call(metrics[metric]["value"], delta)

func metrics_data():
	var data = ""

	for metric in metrics.keys():
		data += metric + " " + str(metrics[metric]["value"]) + "\n"

	return data

func add_metric(name: String, initialValue: float, deltaFunc):
	metrics[name] = {"value": initialValue, "lambda": deltaFunc}
