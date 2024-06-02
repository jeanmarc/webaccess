extends Node

const SERVER_KEY = "res://server.key"
const SERVER_CERT = "res://server.crt"

var bind_port = 9999
var bind_ip = "0.0.0.0"
var use_tls = true

func _ready():
	generate_crypto()

	var server = AnotherHTTPServer.new()
	server.headers["Cross-Origin-Opener-Policy"] = "same-origin"
	server.headers["Cross-Origin-Embedder-Policy"] = "require-corp"

	var error = server.listen(bind_port, bind_ip, use_tls, SERVER_KEY, SERVER_CERT)
	match error:
		OK:
			print("other http server started")
			print("Listening on https://%s:%s" % [bind_ip, bind_port])
		ERR_ALREADY_IN_USE:
			print("Port in use (%s)" % [bind_port])
			server.stop()
		_:
			print("Error starting other server. Errorcode: %d" % error)
			server.stop()

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
