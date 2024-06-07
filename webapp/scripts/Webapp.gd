extends Control

@onready var requestUrlLine = $RequestURL
@onready var replyText: TextEdit = $Reply

var server_host = "localhost"
var server_port = 9998
var peer = WebSocketMultiplayerPeer.new()
var uiInstance: MetricsGui
var id = 0

func _ready():
	var serverCert = load("res://server.crt")
	peer.create_client("wss://%s:%s" % [server_host, server_port], TLSOptions.client_unsafe(serverCert))
	print("started client")

	$SendRequest.pressed.connect(_on_request_button_pressed)
	$SendRequestDirect.pressed.connect(_on_direct_request_button_pressed)
	$Switch3D.pressed.connect(switch_scene)
	
	var ui = preload("res://scenes/metrics_gui.tscn")
	
	uiInstance = ui.instantiate()
	self.add_child(uiInstance)

func _process(delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		print("Receiving data...")
		var packet = peer.get_packet()
		if packet != null:
			var data_string = packet.get_string_from_utf8()
			var data = JSON.parse_string(data_string)
			print(data)

			if data.type == Messages.Type.peerId:
				id = data.id
				print("Received id %s" % id)
			if data.type == Messages.Type.responseData:
				print("Answer is %s" % data.response)
				replyText.clear()
				replyText.insert_text_at_caret(str(data.response))

func _on_direct_request_button_pressed():
	$HTTPRequest.request(requestUrlLine.text)

func _on_request_button_pressed():
	var request = {
		"type": Messages.Type.requestUrl,
		"peer": id,
		"url": requestUrlLine.text
	}
	print("Sending: %s" % JSON.stringify(request))
	peer.put_packet(JSON.stringify(request).to_utf8_buffer())

func _on_request_completed(result, response_code, headers, body):
	var reply = body.get_string_from_utf8()
	print(reply)
	replyText.clear()
	replyText.insert_text_at_caret(reply)

func switch_scene():
	get_tree().change_scene_to_file("res://scenes/metrics_world.tscn")


