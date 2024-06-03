extends Node
class_name Simulator

var metrics={
	"runtime": 0.0,
	"random": 0.0
}

func _ready():
	pass

func _process(delta):
	metrics["runtime"] += delta
	metrics["random"] = randf()

func metrics_data():
	var data = ""

	for metric in metrics.keys():
		data += metric + " " + str(metrics[metric]) + "\n"

	return data
