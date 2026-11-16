extends RefCounted
# gdlint: disable=max-returns
## Bounded, checksummed JSON. A corrupt primary recovers from the previous good slot.
const VERSION = 1
const MAX_BYTES = 65536
var directory := "user://saves"
var last_error := ""
var recovered := false


func _path(suffix: String = "") -> String:
	return directory.path_join("journey.json" + suffix)


func valid(data: Dictionary) -> bool:
	for key in ["x", "y", "hour", "day", "equipped", "facing", "play_seconds"]:
		if not data.has(key) or not (data[key] is float or data[key] is int):
			return false
		if not is_finite(float(data[key])):
			return false
	if data.x < 20 or data.x > 1516 or data.y < 20 or data.y > 1132:
		return false
	if data.hour < 0 or data.hour >= 24 or data.day < 1 or data.day > 100000:
		return false
	if data.equipped < 0 or data.equipped > 4 or data.facing < 0 or data.facing > 3:
		return false
	if data.play_seconds < 0 or data.play_seconds > 1e10:
		return false
	if not data.get("intro_done") is bool or not data.get("beacons") is Array:
		return false
	if data.beacons.size() != 6:
		return false
	for lit in data.beacons:
		if not lit is bool:
			return false
	return true


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("version") != VERSION:
		return {}
	var payload: Variant = envelope.get("payload")
	if not payload is String or envelope.get("sha256") != payload.sha256_text():
		return {}
	if parser.parse(payload) != OK:
		return {}
	var data: Variant = parser.data
	if not data is Dictionary or not valid(data):
		return {}
	return data


func load_game() -> Dictionary:
	recovered = false
	var data := _read(_path())
	if data.is_empty():
		data = _read(_path(".bak"))
		recovered = not data.is_empty()
	return data


func exists() -> bool:
	return not load_game().is_empty()


func save(data: Dictionary) -> bool:
	last_error = ""
	if not valid(data):
		last_error = "Некорректное состояние игры."
		return false
	if FileAccess.file_exists(directory.get_base_dir()):
		return _fail(ERR_ALREADY_EXISTS)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		return _fail(error)
	var payload := JSON.stringify(data)
	var text := JSON.stringify(
		{"version": VERSION, "payload": payload, "sha256": payload.sha256_text()}
	)
	var file := FileAccess.open(_path(".tmp"), FileAccess.WRITE)
	if file == null:
		return _fail(FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return _fail(error)
	# Do not replace a good backup with a corrupted primary.
	if not _read(_path()).is_empty():
		error = DirAccess.copy_absolute(_path(), _path(".bak"))
		if error != OK:
			return _fail(error)
	error = DirAccess.rename_absolute(_path(".tmp"), _path())
	if error != OK:
		return _fail(error)
	return true


func _fail(error: Error) -> bool:
	last_error = "Не удалось записать файл: " + error_string(error)
	return false
