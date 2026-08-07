extends SceneTree
func _init() -> void:
	var svc = load("res://src/core/auth_service.gd").new()
	var r = svc.register("probe_user_1", "pass1234")
	print("REG:", r)
	var r2 = svc.login("probe_user_1", "pass1234")
	print("LOGIN:", r2)
	quit()
