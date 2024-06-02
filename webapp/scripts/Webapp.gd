extends Control

var server_host = "borg"
var server_port = 9998
var peer = WebSocketMultiplayerPeer.new()
var id = 0

func _ready():
	var serverCert = load("res://server.crt")
	peer.create_client("wss://%s:%s" % [server_host, server_port], TLSOptions.client_unsafe(serverCert))
	print("started client")

	$HTTPRequest.request_completed.connect(_on_request_completed)
	$HTTPRequest.request("https://api.github.com/repos/godotengine/godot/releases/latest")

	$GetGithubVersion.pressed.connect(_on_request_button_pressed)

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

func _on_request_button_pressed():
	var request = {
		"type": Messages.Type.requestUrl,
		"url": "https://api.github.com/repos/godotengine/godot/releases/latest"
	}
	print("Sending: %s" % JSON.stringify(request))
	peer.put_packet(JSON.stringify(request).to_utf8_buffer())

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	print(json["name"])

