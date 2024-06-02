extends Node

const SERVER_KEY = "res://server.key"
const SERVER_CERT = "res://server.crt"

func _ready():
	generate_crypto()
	var webappServer = HttpFileRouter.new("../exports")

	var server = HttpServer.new()
	server.register_router("/fib", FibonacciRouter.new())
	server.register_router("/app", webappServer)
	server.enable_cors(["*"])
	add_child(server)
	server.start()

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
