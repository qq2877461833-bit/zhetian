class_name AuthService
extends RefCounted
## 账号服务（核心层 · 纯逻辑）· 多账号用户系统
## MVP：本地存储（GitHub Pages 静态托管无后端；账号+存档存 user://）
## 密码：随机 salt + SHA-256 哈希（本地演示级；正式版需服务端权威 ADR-0003）
## 注意：跨设备不同步（本地账号），正式发布需后端（后续 Phase）

const AUTH_PATH := "user://auth.json"
const SESSION_PATH := "user://session.json"

var _accounts := {}   ## username -> { salt, hash }
var _current_user := ""


func _init() -> void:
	_load_accounts()
	_load_session()


## 注册：返回 { ok, reason }
func register(username: String, password: String) -> Dictionary:
	var name := username.strip_edges()
	if name.length() < 2 or name.length() > 16:
		return { "ok": false, "reason": "用户名需 2-16 字符" }
	if not _valid_name(name):
		return { "ok": false, "reason": "用户名仅限字母/数字/下划线/中文" }
	if _accounts.has(name):
		return { "ok": false, "reason": "用户名已存在" }
	if password.length() < 4:
		return { "ok": false, "reason": "密码至少 4 位" }
	var salt := _gen_salt()
	_accounts[name] = { "salt": salt, "hash": _hash(password, salt) }
	_persist_accounts()
	_current_user = name
	_persist_session()
	return { "ok": true }


## 登录：返回 { ok, reason }
func login(username: String, password: String) -> Dictionary:
	var name := username.strip_edges()
	if not _accounts.has(name):
		return { "ok": false, "reason": "账号不存在，请先注册" }
	var acc: Dictionary = _accounts[name]
	if _hash(password, String(acc.get("salt", ""))) != String(acc.get("hash", "")):
		return { "ok": false, "reason": "密码错误" }
	_current_user = name
	_persist_session()
	return { "ok": true }


## 登出（返回登录界面）
func logout() -> void:
	_current_user = ""
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


func current_user() -> String:
	return _current_user


func is_logged_in() -> bool:
	return not _current_user.is_empty()


## 账号是否存在（供 UI 判断注册/登录模式）
func account_exists(username: String) -> bool:
	return _accounts.has(username.strip_edges())


func _valid_name(name: String) -> bool:
	## 逐字符校验：数字/大小写字母/下划线/中文（is_valid_identifier 对数字字符返回 false，不能用）
	for ch in name:
		var c := ch.unicode_at(0)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or c > 127
		if not ok:
			return false
	return true


func _gen_salt() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for i in range(16):
		out += "%02x" % rng.randi_range(0, 255)
	return out


func _hash(pwd: String, salt: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((salt + pwd).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _load_accounts() -> void:
	if not FileAccess.file_exists(AUTH_PATH):
		return
	var txt := FileAccess.get_file_as_string(AUTH_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		_accounts = parsed


func _persist_accounts() -> void:
	var f := FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_accounts))
	f.close()


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var txt := FileAccess.get_file_as_string(SESSION_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary and _accounts.has(String(parsed.get("user", ""))):
		_current_user = String(parsed.get("user", ""))


func _persist_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({ "user": _current_user }))
	f.close()
