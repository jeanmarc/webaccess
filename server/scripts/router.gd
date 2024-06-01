extends HttpRouter
class_name FibonacciRouter

var f0 = 1
var f1 = 1

func nextFibonacci():
	var result = f0
	var next = f0 + f1
	f0 = f1
	f1 = next
	return result

func handle_get(request, response):
	response.send(200, "Next fibonacci is " + str(nextFibonacci()))
