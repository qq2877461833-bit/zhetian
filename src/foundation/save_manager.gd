extends Node
## 存档管理（基础层 · Autoload: SaveManager）
## 垂直切片：user:// JSON 明文版（加密 + 版本迁移 = ADR-0002，Phase 后续落地）
## 服务端权威原则（ADR-0003）：本地存档仅为缓存/容错，数值最终以服务端为准（切片阶段无服务端，本地为准）
## 注：用 preload 而非 class_name 引用 SaveModel（autoload 解析期早于全局类缓存，preload 保证 headless/CI 确定性）

const SaveModelScript := preload("res://src/core/save_model.gd")
const SAVE_PATH := "user://save.json"


func save(model) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveManager] 存档写入失败: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(model.to_dict()))
	f.close()


## 删除存档（调试/重置用）
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## 加载存档；无档/坏档回退默认档（不崩溃）
func load_save():
	if not FileAccess.file_exists(SAVE_PATH):
		return SaveModelScript.default_save()
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return SaveModelScript.from_dict(parsed)
	push_warning("[SaveManager] 存档解析失败，回退默认档")
	return SaveModelScript.default_save()
