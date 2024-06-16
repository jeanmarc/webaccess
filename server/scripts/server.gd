extends Control

const SERVER_KEY = "res://server.key"
const SERVER_CERT = "res://server.crt"

var bind_port = 9999
var bind_ip = "0.0.0.0"
var use_tls = true

var peer = WebSocketMultiplayerPeer.new()
var users = {}
var rtc_port = 9998

func _ready():
	generate_crypto()

	var web_server = AnotherHTTPServer.new()
	web_server.headers["Cross-Origin-Opener-Policy"] = "same-origin"
	web_server.headers["Cross-Origin-Embedder-Policy"] = "require-corp"

	var error = web_server.listen(bind_port, bind_ip, use_tls, SERVER_KEY, SERVER_CERT)
	match error:
		OK:
			print("other http server started")
			print("Listening on https://%s:%s" % [bind_ip, bind_port])
		ERR_ALREADY_IN_USE:
			print("Port in use (%s)" % [bind_port])
			web_server.stop()
		_:
			print("Error starting other server. Errorcode: %d" % error)
			web_server.stop()

	peer.peer_connected.connect(peer_connected)
	peer.peer_disconnected.connect(peer_disconnected)

	var server_key = load(SERVER_KEY)
	var server_cert = load(SERVER_CERT)

	peer.create_server(rtc_port, "*", TLSOptions.server(server_key, server_cert))


func _process(_delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		print("Received data...")
		var packet = peer.get_packet()
		if packet != null:
			var dataString = packet.get_string_from_utf8()
			var data = JSON.parse_string(dataString)
			print(data)

			if data.type == Messages.Type.requestUrl:
				perform_request(data.peer, data.url)


func generate_crypto(overwrite: bool = false):
	if !(ResourceLoader.exists(SERVER_KEY) && ResourceLoader.exists(SERVER_CERT)) || overwrite:
		print("Generating new crypto...")
		var crypto = Crypto.new()
		var key = crypto.generate_rsa(4096)
		var cert = crypto.generate_self_signed_certificate(key, "CN=demoServer,O=demoOrg,C=NL", "20240101000000", "20341231235959")
		key.save("res://server.key")
		cert.save("res://server.crt")
	else:
		print("Crypto material already present")


func peer_connected(id):
	print("Peer Connected: " + str(id))
	users[id] = {
		"id" : id,
		"type" :  Messages.Type.peerId
	}
	peer.get_peer(id).put_packet(JSON.stringify(users[id]).to_utf8_buffer())

func peer_disconnected(id):
	users.erase(id)

func perform_request(peer_id, request):
	print("Will call %s for %s" % [request, peer_id])
	var new_request = Request.new()
	new_request.perform_request(self, peer, peer_id, request)
