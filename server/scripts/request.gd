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
	print("Request completed with code %s" % response_code)
	var json = JSON.parse_string(body.get_string_from_utf8())
	var reply = {
		"type": Messages.Type.responseData,
		"response": json
	}
	peer.get_peer(requested_for_peer).put_packet(JSON.stringify(reply).to_utf8_buffer())
	print("Pushed reply, bye")
	queue_free()
