extends Node3D

@onready var displays = [$GuiPanel, $GuiPanel2, $GuiPanel3, $GuiPanel4]
var next_panel = 0

func _ready():
	$Timer.timeout.connect(power_on_monitor)
	$Timer.start(1)
	pass

func _input(event):
	if event.is_action("exit"):
		get_tree().quit()


func power_on_monitor():
	if next_panel < displays.size():
		displays[next_panel].power_on("Monitor %s" % next_panel)
		next_panel += 1
		$Timer.start(1.75)
