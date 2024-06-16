extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var _mouse_input := false
var _mouse_rotation: Vector3
var _camera_rotation: Vector3
var _player_rotation: Vector3
var _rotation_input := 0.0
var _tilt_input := 0.0

@export var KEY_ROTATION_FACTOR := 5.0
@export var MOUSE_SENSITIVITY := 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-85.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(85.0)
@export var CAMERA_CONTROLLER: Node3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	CAMERA_CONTROLLER = $CameraController


func _input(event):
	if event.is_action("turn_left"):
		_rotation_input = KEY_ROTATION_FACTOR
	elif event.is_action("turn_right"):
		_rotation_input = -KEY_ROTATION_FACTOR


func _unhandled_input(event):
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x
		_tilt_input = -event.relative.y


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	_update_camera(delta)

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _update_camera(delta):
	_mouse_rotation.x += _tilt_input * delta * MOUSE_SENSITIVITY
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta * MOUSE_SENSITIVITY

	_camera_rotation = Vector3(_mouse_rotation.x, 0.0, 0.0)
	_player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)

	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
	CAMERA_CONTROLLER.rotation.z = 0.0

	global_transform.basis = Basis.from_euler(_player_rotation)

	if not Input.is_action_pressed("turn_left") and not Input.is_action_pressed("turn_right"):
		_rotation_input = 0.0

	_tilt_input = 0.0
