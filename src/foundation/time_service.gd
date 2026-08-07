extends Node
## 时间服务（基础层 · Autoload: TimeService）
## 垂直切片：服务器时间戳骨架——本地时钟占位（真实服务端同步 ADR-0003 后续落地）
## 所有结算一律用 now()（防系统回拨，GDD-001 §3.4）

var server_offset_ms := 0  ## 服务器-本地时钟偏移（切片占位 0）


## 权威时间戳（秒）
func now() -> int:
	return Time.get_unix_time_from_system() + int(server_offset_ms / 1000.0)


## 是否已与服务端同步（切片占位：本地时钟视为权威）
func is_server_synced() -> bool:
	return true
