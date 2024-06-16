extends Control
class_name MetricsGui

var id: int = 0

@onready var requestUrlLine = $RequestURL
@onready var replyText: TextEdit = $Reply
@onready var timer: Timer = $Timer
@onready var progressBar = $TextureProgressBar

var server_host = "localhost"
var server_port = 9998

var metric_value: float:
	set(new_value):
		metric_value = new_value
		progressBar.value = new_value

var peer = WebSocketMultiplayerPeer.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	var serverCert = load("res://server.crt")
	peer.create_client("wss://%s:%s" % [server_host, server_port], TLSOptions.client_unsafe(serverCert))
	print("started client " + str(self.get_path()))

	$HTTPRequest.request_completed.connect(_on_request_completed)
	$SendRequest.pressed.connect(_on_request_button_pressed)
	$SendRequestDirect.pressed.connect(_on_direct_request_button_pressed)
	print("wiring the timer")
	timer.timeout.connect(_on_request_button_pressed)

func _process(_delta):
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
				if data.response.contains("random"):
					replyText.insert_text_at_caret("\nextracting value...\n")
					var all_values = Array(str(data.response).split("\n"))
					replyText.insert_text_at_caret(str(all_values))
					var random_value = all_values.filter(func(s):print("testing " + s );return s.contains("random"))
					print("found value " + str(random_value))
					var rnd = random_value[0].split(" ")[1].to_float()
					metric_value = rnd


func _on_direct_request_button_pressed():
	$HTTPRequest.request(requestUrlLine.text)


func _on_request_button_pressed():
	if id == 0:
		print("Cannot send request, peer id not yet known")
		return
	var request = {
		"type": Messages.Type.requestUrl,
		"peer": id,
		"url": requestUrlLine.text
	}
	print("Sending: %s" % JSON.stringify(request))
	peer.put_packet(JSON.stringify(request).to_utf8_buffer())

func _on_request_completed(result, response_code, _headers, body):
	if result != 0 and response_code != 200:
		print("Request failed (result=%s, code=%s)" % [result, response_code])
	else:
		var reply = body.get_string_from_utf8()
		print(reply)
		replyText.clear()
		replyText.insert_text_at_caret(reply)


func startPolling():
	print("Start polling " + str(self.get_path()))
	timer.start(1)
