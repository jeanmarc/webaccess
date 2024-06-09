extends Node3D


func _input(event):
	if event.is_action("exit"):
		get_tree().quit()
