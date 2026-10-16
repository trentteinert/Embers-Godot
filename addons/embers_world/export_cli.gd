extends SceneTree
## Command line export (no editor window):
##   godot --headless --path <project> -s res://addons/embers_world/export_cli.gd -- scene=res://world.tscn out=/path/to/dir [check]
func _init() -> void:
	var scene := ""
	var out := "res://embers_export"
	var write := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scene = a.get_slice("=", 1)
		elif a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a == "check":
			write = false
	var ps: PackedScene = load(scene)
	if ps == null:
		print("EMBERS-EXPORT FAIL cannot load ", scene)
		quit(1)
		return
	var root := ps.instantiate()
	get_root().add_child(root)
	await process_frame
	var r := EmbersExporter.run(root, out, write)
	for e: String in r["errors"]:
		print("ERROR: ", e)
	for w: String in r["warnings"]:
		print("WARNING: ", w)
	print("EMBERS-EXPORT ", "OK " if r["ok"] else "FAIL ", JSON.stringify(r["stats"]))
	quit(0 if r["ok"] else 1)
