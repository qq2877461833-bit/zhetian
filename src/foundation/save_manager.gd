extends Node
## 存档管理（基础层 · Autoload: SaveManager）
## 多账号：存档按账号隔离 user://saves/<username>.json
## 兼容：无账号时用旧 save.json（guest 账号继承）；老玩家不丢档
## 服务端权威原则（ADR-0003）：本地存档仅为缓存/容错（切片阶段无服务端，本地为准）

const SaveModelScript := preload("res://src/core/save_model.gd")
const LEGACY_PATH := "user://save.json"


func _saves_dir() -> String:
	var d := "user://saves"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(d)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	return d


func _path_for(user: String) -> String:
	return "%s/%s.json" % [_saves_dir(), user]


## 存档（按账号）；user 为空时写入旧路径（兼容）
func save(model, user: String = "") -> void:
	var path := _path_for(user) if not user.is_empty() else LEGACY_PATH
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveManager] 存档写入失败: %s" % path)
		return
	f.store_string(JSON.stringify(model.to_dict()))
	f.close()


## 删除存档（调试/重置用；按账号）
func delete_save(user: String = "") -> void:
	var path := _path_for(user) if not user.is_empty() else LEGACY_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 加载存档；无档/坏档回退默认档（不崩溃）
## user 为空：优先旧 save.json（guest 迁移）
func load_save(user: String = ""):
	var path := _path_for(user) if not user.is_empty() else LEGACY_PATH
	if not FileAccess.file_exists(path):
		## guest 场景：旧档存在则迁移为 guest 存档
		if user == "guest" and FileAccess.file_exists(LEGACY_PATH):
			path = LEGACY_PATH
		else:
			return SaveModelScript.default_save()
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return SaveModelScript.from_dict(parsed)
	push_warning("[SaveManager] 存档解析失败，回退默认档")
	return SaveModelScript.default_save()
