extends Node
## Automated test node for AIClient HTTP communication, timeouts, offline handling,
## and live Python AI backend integration.

func _ready() -> void:
	print("--- Running BioSphere-X AI Client Tests ---")
	_run_tests()


func _run_tests() -> void:
	var client_script: GDScript = load("res://scripts/autoloads/ai_client.gd")
	assert(client_script != null, "AIClient script must load")
	
	var client: Node = client_script.new()
	client.name = "AIClientTest"
	add_child(client)
	
	# 1. API Methods Existence Check
	assert(client.has_method("check_health"), "check_health method must exist")
	assert(client.has_method("send_test"), "send_test method must exist")
	assert(client.has_method("send_test_echo"), "send_test_echo method must exist")
	assert(client.has_method("request_path"), "request_path method must exist")
	print("  [PASS] Asynchronous API methods verified")
	
	# 2. Verification of Offline / Graceful Degradation Handling
	client.set("base_url", "http://127.0.0.1:59999")
	client.set("timeout_seconds", 0.5)
	
	var test_offline := {"done": false, "res": {}}
	client.call("check_health", func(res: Dictionary) -> void:
		test_offline["done"] = true
		test_offline["res"] = res
	)
	
	var start_msec := Time.get_ticks_msec()
	while not test_offline["done"] and (Time.get_ticks_msec() - start_msec) < 2000:
		await get_tree().process_frame
	
	assert(test_offline["done"], "Offline request must complete and invoke callback")
	var offline_res: Dictionary = test_offline["res"]
	assert(offline_res.get("success") == false, "Offline request must report success = false")
	assert(client.get("is_backend_available") == false, "Backend availability must be false when offline")
	assert(offline_res.has("error"), "Offline result must contain an error description")
	print("  [PASS] Offline / unavailable backend handling verified (Error: '%s')" % offline_res.get("error"))
	
	# 3. Live Online Python Backend Communication
	client.set("base_url", "http://127.0.0.1:8000")
	client.set("timeout_seconds", 3.0)
	
	# A. Health Check
	var health_test := {"done": false, "res": {}}
	client.call("check_health", func(res: Dictionary) -> void:
		health_test["done"] = true
		health_test["res"] = res
	)
	start_msec = Time.get_ticks_msec()
	while not health_test["done"] and (Time.get_ticks_msec() - start_msec) < 3000:
		await get_tree().process_frame
	
	assert(health_test["done"], "Live health check must complete")
	var health_res: Dictionary = health_test["res"]
	assert(health_res.get("success") == true, "Live health check must succeed")
	assert(client.get("is_backend_available") == true, "Backend must report available = true")
	var data: Dictionary = health_res.get("data", {})
	assert(data.get("status") == "ok", "Backend status must be 'ok'")
	print("  [PASS] Live health check verified: ", data.get("service"), " v", data.get("version"))
	
	# B. Test Echo Endpoint (POST JSON)
	var echo_test := {"done": false, "res": {}}
	client.call("send_test_echo", "Godot-Astronaut-Signal", {"suit_integrity": 100, "oxygen": 98.5}, func(res: Dictionary) -> void:
		echo_test["done"] = true
		echo_test["res"] = res
	)
	start_msec = Time.get_ticks_msec()
	while not echo_test["done"] and (Time.get_ticks_msec() - start_msec) < 3000:
		await get_tree().process_frame
	
	assert(echo_test["done"], "Live echo request must complete")
	var echo_res: Dictionary = echo_test["res"]
	assert(echo_res.get("success") == true, "Echo request must succeed")
	var echo_data: Dictionary = echo_res.get("data", {})
	assert(echo_data.get("status") == "success", "Echo response status must be 'success'")
	assert("Godot-Astronaut-Signal" in echo_data.get("message", ""), "Echo must echo back the message")
	print("  [PASS] Live JSON echo verified: '%s'" % echo_data.get("message"))
	
	# C. Pathfinding Endpoint
	var path_test := {"done": false, "res": {}}
	var blocked_cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1)]
	client.call("request_path", Vector2i(0, 0), Vector2i(3, 3), blocked_cells, func(res: Dictionary) -> void:
		path_test["done"] = true
		path_test["res"] = res
	)
	start_msec = Time.get_ticks_msec()
	while not path_test["done"] and (Time.get_ticks_msec() - start_msec) < 3000:
		await get_tree().process_frame
	
	assert(path_test["done"], "Live path request must complete")
	var path_res: Dictionary = path_test["res"]
	assert(path_res.get("success") == true, "Path request must succeed")
	var path_data: Dictionary = path_res.get("data", {})
	assert(path_data.get("found") == true, "Path must be found")
	assert(path_data.get("length") > 0, "Path length must be > 0")
	print("  [PASS] Live Python A* pathfinding verified (Path length: %d nodes)" % path_data.get("length"))
	
	client.queue_free()
	print("--- All BioSphere-X AI Client Tests Passed! ---")
	get_tree().quit(0)
