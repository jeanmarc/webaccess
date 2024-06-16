class_name GuiPanel
extends Node3D

static var feed_scene = preload("res://scenes/metrics_gui.tscn")

@onready var subviewport = $SubViewport
@onready var label = $Label3D
@onready var display = $MonitorOutput

# Called when the node enters the scene tree for the first time.
func _ready():
	print("GuiPanel _ready " + str(self.get_path()))
	pass

func power_on(name: String):
	print("power_on " + str(self.get_path()))
	var feed_instance = feed_scene.instantiate()
	label.text = name
	subviewport.add_child(feed_instance)
	display.visible = true
	feed_instance.call_deferred("startPolling")

