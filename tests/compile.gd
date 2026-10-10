extends Node
func _ready() -> void:
	for p in ['res://scripts/asset_gallery.gd', 'res://scripts/audio.gd', 'res://scripts/camera_rig.gd', 'res://scripts/clicker.gd', 'res://scripts/combat.gd', 'res://scripts/crafting.gd', 'res://scripts/data.gd', 'res://scripts/enemy.gd', 'res://scripts/items.gd', 'res://scripts/main.gd', 'res://scripts/models.gd', 'res://scripts/player.gd', 'res://scripts/quests.gd', 'res://scripts/rig.gd', 'res://scripts/skills.gd', 'res://scripts/sprite_art.gd', 'res://scripts/town_kit.gd', 'res://scripts/ui.gd', 'res://scripts/world.gd']:
		var s: Script = load(p)
		print(p, " ok=", s != null and s.can_instantiate())
	get_tree().quit()
