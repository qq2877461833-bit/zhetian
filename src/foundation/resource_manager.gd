extends Node
## 资源管理（基础层 · Autoload: ResourceManager）
## 垂直切片：本地 FileAccess 读取数据表（res://data/tables/*.json）
## 远程 Bundle / manifest 协议（ARCH-ENG-006 §2.2 / foundation-protocols §2）后续落地


## 读取 JSON 数据表；文件缺失/解析失败返回空表并告警（禁静默失败）
func load_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[ResourceManager] 数据表不存在: %s" % path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		push_warning("[ResourceManager] 数据表为空: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	push_warning("[ResourceManager] 数据表 JSON 解析失败: %s" % path)
	return {}
