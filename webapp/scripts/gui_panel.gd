extends Node3D

@onready var subviewport = $SubViewport

# Called when the node enters the scene tree for the first time.
func _ready():
	var gui = preload("res://scenes/metrics_gui.tscn")
	var guiInstance = gui.instantiate()
	subviewport.add_child(guiInstance)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
