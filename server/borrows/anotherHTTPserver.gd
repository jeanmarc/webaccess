# A full HTTP server for Godot
# Copyright (c) Anutrix(Numan Zaheer Ahmed)
# MIT License
# Based and inspired from Godot Engine Editor's HTTP Server and GodotTPD
# Note: Treat this file as Alpha level. Unsure about threads and lock logic too.

extends Node
class_name AnotherHTTPServer

const SERVER_APP_NAME: String = "AnotherHTTPServer"
const MAX_CHUNK_SIZE: int = 4096

var access_control_origin: String = "*"
var access_control_allowed_methods: String = "POST, GET, OPTIONS"
var access_control_allowed_headers: String = "content-type"

var server: TCPServer = null
var mimes: Dictionary = {}
var tcp: StreamPeerTCP = null
var tls: StreamPeerTLS = null
var peer: StreamPeer = null
var key: CryptoKey = null
var cert: X509Certificate = null
var use_tls: bool = false
var time: int = 0
var req_buf: PackedByteArray = []
var req_pos: int = 0
var server_quit_flag_set: bool = false
var server_lock: Mutex = Mutex.new()
var server_thread: Thread = Thread.new()

var cookie_store: Array[String] = []
var headers: Dictionary = {}

func _init() -> void:
	mimes["html"] = "text/html"
	mimes["js"] = "application/javascript"
	mimes["json"] = "application/json"
	mimes["pck"] = "application/octet-stream"
	mimes["png"] = "image/png"
	mimes["svg"] = "image/svg"
	mimes["wasm"] = "application/wasm"

	mimes["zip"] = "application/octet-stream"
	mimes["txt"] = "text/html"

	server = TCPServer.new()
	stop()

func start() -> void:
	set_process(true)

func stop() -> void:
	server_quit_flag_set = true
	if server_thread.is_started():
		server_thread.wait_to_finish()
	if is_instance_valid(server):
		server.stop()
	_clear_client()

	set_process(false)

func _clear_client() -> void:
	peer = null # Is this correct?
	if tls:
		tls.disconnect_from_stream()
		tls = null
	if tcp:
		tcp.disconnect_from_host()
		tcp = null
	req_buf.clear()
	time = 0
	req_pos = 0

func listen(p_port: int, p_address: String, p_use_tls: bool, p_tls_key: String, p_tls_cert: String) -> Error:
	server_lock.lock()

	if server.is_listening():
		return ERR_ALREADY_IN_USE

	use_tls = p_use_tls
	if use_tls:
		var crypto: Crypto = Crypto.new()
		if crypto == null:
			return ERR_UNAVAILABLE

		if !p_tls_key.is_empty() and !p_tls_cert.is_empty():
			key = CryptoKey.new()
			var err: Error = key.load(p_tls_key)
			if err != OK:
				print("err", err)
				stop()
				return FAILED
			cert = X509Certificate.new()
			err = cert.load(p_tls_cert)
			if err != OK:
				print("err", err)
				stop()
				return FAILED
		else:
			_set_internal_certs(crypto)

	var err_listen: Error = server.listen(p_port, p_address)
	if err_listen == OK:
		server_quit_flag_set = false
		var err_thread_start: Error = server_thread.start(_server_thread_poll)
		if err_thread_start != OK:
			print("Error: ", err_thread_start)
			stop()

	server_lock.unlock()
	return err_listen

func _set_internal_certs(p_crypto: Crypto) -> void:
	const cache_path: String = "res://"
	var key_path: String = cache_path.path_join("html5_server.key")
	var crt_path: String = cache_path.path_join("html5_server.crt")
	var regen: bool = !FileAccess.file_exists(key_path) || !FileAccess.file_exists(crt_path)
	if !regen:
		key = CryptoKey.new()
		cert = X509Certificate.new()
		if key.load(key_path) != OK || cert.load(crt_path) != OK:
			regen = true

	if regen:
		print("Regenerating key and cert.")
		key = p_crypto.generate_rsa(2048)
		var key_err: Error = key.save(key_path)
		if key_err != OK:
			print("Error saving key.")
		cert = p_crypto.generate_self_signed_certificate(key, "CN=godot-debug.local,O=A Game Dev,C=XXA", "20140101000000", "20340101000000")
		var crt_err: Error = cert.save(crt_path)
		if crt_err != OK:
			print("Error saving cert.")
	else:
		print("Reusing existing key and cert.")

	#var key_file: FileAccess = FileAccess.open(key_path, FileAccess.READ)
	#print(key_file.get_as_text())
	#var crt_file: FileAccess = FileAccess.open(crt_path, FileAccess.READ)
	#print(crt_file.get_as_text())

func _server_thread_poll() -> void:
	while (!server_quit_flag_set == true):
		OS.delay_usec(6900)

		server_lock.lock()
		_poll()
		server_lock.unlock()

func _poll() -> void:
	if !server.is_listening():
		return

	if tcp == null:
		if !server.is_connection_available():
			return

		tcp = server.take_connection()
		peer = tcp
		time = Time.get_ticks_usec()

	if Time.get_ticks_usec() - time > 1000000:
		_clear_client()
		return

	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return

	if use_tls:
		if tls == null:
			tls = StreamPeerTLS.new()
			peer = tls
			if tls.accept_stream(tcp, TLSOptions.server(key, cert)) != OK:
				_clear_client()
				return
		tls.poll()
		var status: int = tls.get_status()
		if status == StreamPeerTLS.STATUS_HANDSHAKING:
			# Still handshaking, keep waiting.
			return
		if status != StreamPeerTLS.STATUS_CONNECTED:
			_clear_client()
			return

	while (true):
		var r: PackedByteArray = req_buf.duplicate()
		var l: int = req_pos - 1
		if (l > 3 and char(r[l]) == '\n' and char(r[l - 1]) == '\r' and char(r[l - 2]) == '\n' and char(r[l - 3]) == '\r'):
			_send_response()
			_clear_client()
			return

		#if (req_pos >= 4096):
			#print("req_pos >= 4096")
			#return

		var dat: Array = peer.get_data(1)
		var err: Error = dat[0]
		req_buf.append_array(dat[1])

		if err != OK:
			# Got an error
			_clear_client()
			#break
			return

		req_pos += 1

func _send_response() -> void:
	var response_data_buffer_array: Array[String] = []

	var data: String = req_buf.get_string_from_utf8()
	print("\n---Start of Request----")
	print(data)
	print("----End of Request-----\n")

	var psa: PackedStringArray = data.split("\r\n")
	var sze: int = psa.size()
	if sze < 4:
		print("Not enough response headers, got: " + str(sze) + ", expected >= 4.")

	var req: PackedStringArray = psa[0].split(" ", false)
	if req.size() < 2:
		print("Invalid protocol or status code.")

	# Wrong protocol
	if(req[0] != "GET" || req[2] != "HTTP/1.1"):
		print("Invalid method or HTTP version.")

	var query_index: int = req[1].find('?')
	var path: String = ""
	if query_index == -1:
		path = req[1]
	else:
		path = req[1].substr(0, query_index)

	var req_file: String = path.get_file()
	var req_ext: String = path.get_extension()
	var cache_path: String = "res://Data"
	var filepath: String = cache_path.path_join(req_file)

	if !mimes.has(req_ext) || !FileAccess.file_exists(filepath):
		peer_put_bytes(get_headers(404))
		send_response_payload("Not Found")
		return

	var ctype: String = mimes[req_ext]

	var res_file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if res_file == null:
		print("Couldn't access file.")
		response_data_buffer_array.append("\r\n\r\n")
		return

	var file_content: String = res_file.get_as_text()
	if file_content.is_empty():
		print("Empty file")
		peer_put_bytes(get_headers(204, ctype))
		return

	peer_put_bytes(get_headers(200, ctype))

	send_response_payload(file_content)

func send_response_payload(data: String) -> void:
	var response_payload: Array[PackedByteArray] = []

	var clen: int = data.length()
	if clen > 0:
		if clen < MAX_CHUNK_SIZE:
			response_payload.append(str_to_bytes("Content-Length:" + str(clen) + "\r\n\r\n"))
			response_payload.append(str_to_bytes(data))
		else:
			response_payload.append(str_to_bytes("Transfer-Encoding: chunked\r\n\r\n"))
			response_payload.append_array(str_to_chunks(data))
			response_payload.append(str_to_bytes("0\r\n\r\n"))

	peer_put_bytes(response_payload)

func peer_put_bytes(response_data_buffer_array: Array[PackedByteArray]) -> void:
	for item: PackedByteArray in response_data_buffer_array:
		var err: Error = peer.put_data(item)
		if err != OK:
			print("Error in peer.put_data: ", err, " for: ", item)

func add_cookie(cookie_name: String, cookie_value: String, options: Dictionary = {}) -> void:
	var cookie: String = cookie_name + "=" + cookie_value

	if options.has("domain"):
		cookie += "; Domain=" + options["domain"]
	if options.has("max-age"):
		cookie += "; Max-Age=" + options["max-age"]
	if options.has("expires"):
		cookie += "; Expires=" + options["expires"]
	if options.has("path"):
		cookie += "; Path=" + options["path"]
	if options.has("secure"):
		cookie += "; Secure"
	if options.has("httpOnly"):
		cookie += "; HttpOnly"
	if options.has("sameSite"):
		match (options["sameSite"]):
			true: cookie += "; SameSite=Strict"
			"lax": cookie += "; SameSite=Lax"
			"strict": cookie += "; SameSite=Strict"
			"none": cookie += "; SameSite=None"
			_: pass

	cookie_store.append(cookie)

func is_listening() -> bool:
	server_lock.lock()
	var res: bool = server.is_listening()
	server_lock.unlock()
	return res

func _match_status_code(code: int) -> String:
	var text: String = "OK"
	match(code):
		# 1xx - Informational Responses
		100: text="Continue"
		101: text="Switching protocols"
		102: text="Processing"
		103: text="Early Hints"
		# 2xx - Successful Responses
		200: text="OK"
		201: text="Created"
		202: text="Accepted"
		203: text="Non-Authoritative Information"
		204: text="No Content"
		205: text="Reset Content"
		206: text="Partial Content"
		207: text="Multi-Status"
		208: text="Already Reported"
		226: text="IM Used"
		# 3xx - Redirection Messages
		300: text="Multiple Choices"
		301: text="Moved Permanently"
		302: text="Found (Previously 'Moved Temporarily')"
		303: text="See Other"
		304: text="Not Modified"
		305: text="Use Proxy"
		306: text="Switch Proxy"
		307: text="Temporary Redirect"
		308: text="Permanent Redirect"
		# 4xx - Client Error Responses
		400: text="Bad Request"
		401: text="Unauthorized"
		402: text="Payment Required"
		403: text="Forbidden"
		404: text="Not Found"
		405: text="Method Not Allowed"
		406: text="Not Acceptable"
		407: text="Proxy Authentication Required"
		408: text="Request Timeout"
		409: text="Conflict"
		410: text="Gone"
		411: text="Length Required"
		412: text="Precondition Failed"
		413: text="Payload Too Large"
		414: text="URI Too Long"
		415: text="Unsupported Media Type"
		416: text="Range Not Satisfiable"
		417: text="Expectation Failed"
		418: text="I'm a Teapot"
		421: text="Misdirected Request"
		422: text="Unprocessable Entity"
		423: text="Locked"
		424: text="Failed Dependency"
		425: text="Too Early"
		426: text="Upgrade Required"
		428: text="Precondition Required"
		429: text="Too Many Requests"
		431: text="Request Header Fields Too Large"
		451: text="Unavailable For Legal Reasons"
		# 5xx - Server Error Responses
		500: text="Internal Server Error"
		501: text="Not Implemented"
		502: text="Bad Gateway"
		503: text="Service Unavailable"
		504: text="Gateway Timeout"
		505: text="HTTP Version Not Supported"
		506: text="Variant Also Negotiates"
		507: text="Insufficient Storage"
		508: text="Loop Detected"
		510: text="Not Extended"
		511: text="Network Authentication Required"
	return text

func getDateTimeUTCString() -> String:
	const dayOfWeek: Array[String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	const monthOfYear: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	var dt: Dictionary = Time.get_datetime_dict_from_system(true)
	dt.weekday = dayOfWeek[dt.weekday]
	dt.day = "%02d" % dt.day
	dt.month = monthOfYear[dt.month-1]
	dt.hour = "%02d" % dt.hour
	dt.minute = "%02d" % dt.minute
	dt.second = "%02d" % dt.second
	var datetime_str: String = "{weekday}, {day} {month} {year} {hour}:{minute}:{second} GMT".format(dt)
	return datetime_str

func get_headers(status_code: int, content_type: String = "text/html") -> Array[PackedByteArray]:
	var str_array: Array[String] = []

	str_array.append("HTTP/1.1 %d %s\r\n" % [status_code, _match_status_code(status_code)])
	str_array.append("Server: %s\r\n" % SERVER_APP_NAME)
	for header: String in headers.keys():
		str_array.append("%s: %s\r\n" % [header, headers[header]])
	for cookie: String in cookie_store:
		str_array.append(("Set-Cookie: %s\r\n" % cookie))
	str_array.append("Connection: close\r\n")
	str_array.append("Access-Control-Allow-Origin: %s\r\n" % access_control_origin)
	str_array.append("Access-Control-Allow-Methods: %s\r\n" % access_control_allowed_methods)
	str_array.append("Access-Control-Allow-Headers: %s\r\n" % access_control_allowed_headers)
	str_array.append("Content-Type: %s\r\n" % content_type)
	str_array.append("Date: %s\r\n" % getDateTimeUTCString())

	# Convert to bytes and return
	var bytes_array: Array[PackedByteArray] = []
	for s: String in str_array:
		bytes_array.append(str_to_bytes(s))

	return bytes_array

func str_to_bytes(data_str: String) -> PackedByteArray:
	return data_str.to_utf8_buffer()

func str_to_chunks(data_str: String) -> Array[PackedByteArray]:
	var data_bytes: PackedByteArray = data_str.to_utf8_buffer()
	var data_bytes_size: int = data_bytes.size()

	var chunks: Array[PackedByteArray] = []

	var curr_pos: int = 0
	while(curr_pos < data_bytes_size):
		var remaining_len: int = data_bytes_size - curr_pos
		if remaining_len > MAX_CHUNK_SIZE:
			remaining_len = MAX_CHUNK_SIZE

		var chunk: PackedByteArray = ("%X" % remaining_len).to_utf8_buffer()
		chunk.append_array("\r\n".to_utf8_buffer())
		chunk.append_array(data_bytes.slice(curr_pos, curr_pos + remaining_len))
		chunk.append_array("\r\n".to_utf8_buffer())

		chunks.append(chunk)

		curr_pos += MAX_CHUNK_SIZE

	return chunks
