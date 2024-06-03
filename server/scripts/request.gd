extends Node
class_name Request

var requested_for_peer: int = 0
var peer: WebSocketMultiplayerPeer


func perform_request(parent, websocket, peer_id, request):
	print("Calling %s for %s" % [request, peer_id])
	var http_request = HTTPRequest.new()
	peer = websocket
	requested_for_peer = peer_id

	parent.add_child(http_request)
	parent.add_child(self)
	http_request.request_completed.connect(_on_request_completed)
	http_request.request(request)

func _on_request_completed(result, response_code, headers, body):
	print("Request completed with result %s, response_code %s" % [resultString(result), response_code])
	var json = JSON.parse_string(body.get_string_from_utf8())
	var reply = {
		"type": Messages.Type.responseData,
		"response": json
	}
	peer.get_peer(requested_for_peer).put_packet(JSON.stringify(reply).to_utf8_buffer())
	print("Pushed reply, bye")
	queue_free()

var resultDict= {
	HTTPRequest.RESULT_SUCCESS :"RESULT_SUCCESS",
	HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH :"RESULT_CHUNKED_BODY_SIZE_MISMATCH",
	HTTPRequest.RESULT_CANT_CONNECT :"RESULT_CANT_CONNECT",
	HTTPRequest.RESULT_CANT_RESOLVE :"RESULT_CANT_RESOLVE",
	HTTPRequest.RESULT_CONNECTION_ERROR :"RESULT_CONNECTION_ERROR",
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR :"RESULT_TLS_HANDSHAKE_ERROR",
	HTTPRequest.RESULT_NO_RESPONSE :"RESULT_NO_RESPONSE",
	HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED :"RESULT_BODY_SIZE_LIMIT_EXCEEDED",
	HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED :"RESULT_BODY_DECOMPRESS_FAILED",
	HTTPRequest.RESULT_REQUEST_FAILED :"RESULT_REQUEST_FAILED",
	HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN :"RESULT_DOWNLOAD_FILE_CANT_OPEN",
	HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR :"RESULT_DOWNLOAD_FILE_WRITE_ERROR",
	HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED :"RESULT_REDIRECT_LIMIT_REACHED",
	HTTPRequest.RESULT_TIMEOUT :"RESULT_TIMEOUT"
}
func resultString(result: int):
	return resultDict[result]
