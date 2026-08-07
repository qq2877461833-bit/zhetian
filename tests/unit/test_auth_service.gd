extends GutTest
## AuthService unit tests (account system)
## NOTE: writes to real user:// files - uses unique usernames, cleans up after

var svc: AuthService
var _test_users := []


func before_each() -> void:
	svc = AuthService.new()
	_test_users = []


func after_each() -> void:
	for u in _test_users:
		var f := "user://saves/%s.json" % u
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func test_register_and_login() -> void:
	var uname := "tester_%d" % Time.get_ticks_msec()
	_test_users.append(uname)
	var r: Dictionary = svc.register(uname, "pass1234")
	assert_true(r.get("ok", false), "register ok")
	var r2: Dictionary = svc.login(uname, "pass1234")
	assert_true(r2.get("ok", false), "login ok")
	assert_eq(svc.current_user(), uname, "current user")


func test_register_duplicate_fails() -> void:
	var uname := "dup_%d" % Time.get_ticks_msec()
	_test_users.append(uname)
	svc.register(uname, "pass1234")
	var r: Dictionary = svc.register(uname, "other456")
	assert_false(r.get("ok", true), "duplicate rejected")
	assert_true(String(r.get("reason", "")).contains("已存在"), "reason says exists")


func test_login_wrong_password_fails() -> void:
	var uname := "pwd_%d" % Time.get_ticks_msec()
	_test_users.append(uname)
	svc.register(uname, "pass1234")
	var r := svc.login(uname, "wrong999")
	assert_false(r.get("ok", true), "wrong pwd rejected")


func test_login_nonexistent_fails() -> void:
	var r := svc.login("no_such_user_%d" % Time.get_ticks_msec(), "pass1234")
	assert_false(r.get("ok", true), "nonexistent rejected")


func test_short_password_rejected() -> void:
	var r: Dictionary = svc.register("short_%d" % Time.get_ticks_msec(), "123")
	assert_false(r.get("ok", true), "short pwd rejected")


func test_short_username_rejected() -> void:
	var r: Dictionary = svc.register("a", "pass1234")
	assert_false(r.get("ok", true), "short name rejected")


func test_passwords_not_stored_in_plaintext() -> void:
	var uname := "hash_%d" % Time.get_ticks_msec()
	_test_users.append(uname)
	svc.register(uname, "secret123")
	var txt := FileAccess.get_file_as_string("user://auth.json")
	assert_false(txt.contains("secret123"), "no plaintext pwd")
