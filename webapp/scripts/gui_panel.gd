extends Node3D

@onready var subviewport = $SubViewport

# Called when the node enters the scene tree for the first time.
func _ready():
	var gui = preload("res://scenes/metrics_gui.tscn")
	var guiInstance = gui.instantiate()
	subviewport.add_child(guiInstance)
