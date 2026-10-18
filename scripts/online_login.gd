class_name OnlineLogin
extends CanvasLayer
## The login screen for online play: server address, account, password and which world to play in. It
## replaces the launch arguments (--online, --account, ...), which still work. It opens by itself when the game
## starts without them; "Single player" closes it and gives you the normal title screen.
## Remembers the server, account and world (never the password) in user://embers_login.cfg.

const BG := Color(0.075, 0.06, 0.105, 0.97)
const LINE := Color("5a4a6a")
const TEXT := Color("e8dcc8")
const MUTED := Color("9a8fa8")
const EMBER := Color("f2994a")
const BAD := Color("e8806a")
const SAVE := "user://embers_login.cfg"
const ORIGINAL := "The original world"

var main: Node
var _panel: PanelContainer
var _server: LineEdit
var _account: LineEdit
var _password: LineEdit
var _world: OptionButton
var _mode_login: Button
var _mode_register: Button
var _play: Button
var _msg: Label
var _worlds: Array = []   # scene path per _world item ("" = the original)
var _register := false
var _open_btn: Button
var _busy := false


## Called by Main after the title screen is up. Does nothing when the game was started with --online.
static func attach(m: Node) -> void:
	if Online.requested():
		return
	var l: OnlineLogin = OnlineLogin.new()
	l.name = "OnlineLogin"
	m.add_child(l)
	l.setup(m)


func setup(m: Node) -> void:
	main = m
	layer = 40
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build(root)
	_load()
	var err: String = str(Online.cfg.get("error", ""))
	Online.cfg.erase("error")
	if err != "":
		_say(err, true)
	# the button that brings the form back after "Single player"
	_open_btn = Button.new()
	_open_btn.text = "PLAY ONLINE"
	_open_btn.focus_mode = Control.FOCUS_NONE
	_open_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_open_btn.offset_left = -110
	_open_btn.offset_right = 110
	_open_btn.offset_top = -90
	_open_btn.offset_bottom = -50
	_open_btn.add_theme_font_size_override("font_size", 18)
	_open_btn.pressed.connect(func() -> void: _show(true))
	root.add_child(_open_btn)
	_show(true)
	# `--login-demo account|password|world|register` fills the form and presses PLAY (for scripted checks)
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = a.find("--login-demo")
	if i >= 0 and i + 1 < a.size() and not Online.cfg.has("demo_done"):
		Online.cfg["demo_done"] = true
		var parts: PackedStringArray = a[i + 1].split("|")
		_account.text = parts[0]
		_password.text = parts[1]
		_world.select(maxi(0, _worlds.find(parts[2])))
		_set_mode(parts[3] == "1")
		get_tree().create_timer(1.0).timeout.connect(_submit)


var _t := 0.0


func _process(d: float) -> void:
	_t += d
	var shot: String = Online.arg("--login-shot")   # scripted check: save a screenshot of this screen and quit
	if shot != "" and _t > 2.5:
		get_viewport().get_texture().get_image().save_png(shot)
		print("saved ", shot)
		get_tree().quit(0)
	# only while the title screen is up
	var title: bool = main.mode == "title" and not Online.active
	if not title:
		_panel.visible = false
		_open_btn.visible = false
	else:
		_open_btn.visible = not _panel.visible


func _show(on: bool) -> void:
	_panel.visible = on
	_open_btn.visible = not on
	if on:
		main.ui.title_root.visible = false
	else:
		main.ui.title_root.visible = true


func _style(col: Color, border := LINE, w := 2, r := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(r)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


func _label(t: String, size := 14, col := TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _field(parent: Control, caption: String, hint: String, secret := false) -> LineEdit:
	parent.add_child(_label(caption, 13, MUTED))
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.secret = secret
	e.custom_minimum_size = Vector2(380, 36)
	e.add_theme_font_size_override("font_size", 16)
	e.text_submitted.connect(func(_t: String) -> void: _submit())
	parent.add_child(e)
	return e


func _build(root: Control) -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(BG))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	var title := _label("EMBERS OF THORNVALE", 26, EMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("Play online", 15, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	_mode_login = _tab("Log in", false)
	_mode_register = _tab("Create account", true)
	tabs.add_child(_mode_login)
	tabs.add_child(_mode_register)
	_server = _field(v, "Server", "ws://127.0.0.1:7777")
	_account = _field(v, "Account name", "3-20 letters, numbers or _")
	_password = _field(v, "Password", "at least 8 characters to create an account", true)
	v.add_child(_label("World", 13, MUTED))
	_world = OptionButton.new()
	_world.custom_minimum_size = Vector2(380, 36)
	_fill_worlds()
	v.add_child(_world)
	_msg = _label("", 14, BAD)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(380, 0)
	v.add_child(_msg)
	_play = Button.new()
	_play.text = "PLAY"
	_play.focus_mode = Control.FOCUS_NONE
	_play.custom_minimum_size = Vector2(0, 46)
	_play.add_theme_font_size_override("font_size", 20)
	_play.pressed.connect(_submit)
	v.add_child(_play)
	var single := Button.new()
	single.text = "Single player instead"
	single.focus_mode = Control.FOCUS_NONE
	single.flat = true
	single.add_theme_color_override("font_color", MUTED)
	single.pressed.connect(func() -> void: _show(false))
	v.add_child(single)
	_set_mode(false)


func _tab(t: String, register: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: _set_mode(register))
	return b


func _set_mode(register: bool) -> void:
	_register = register
	_mode_login.button_pressed = not register
	_mode_register.button_pressed = register
	_play.text = "CREATE ACCOUNT AND PLAY" if register else "PLAY"
	_say("", false)


func _say(t: String, bad: bool) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", BAD if bad else MUTED)


# ---------------------------------------------------------------- worlds
func _fill_worlds() -> void:
	_worlds = [""]
	_world.add_item(ORIGINAL)
	_scan("res://", 0)
	for p: String in _worlds.slice(1):
		_world.add_item(p.get_file().get_basename().replace("_", " ").capitalize() + "  (your world)")


## Scenes that use the Embers World addon (they contain an EmbersWorld node).
func _scan(dir: String, depth: int) -> void:
	if depth > 3:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		if sub in ["addons", ".godot", "tests", "demo", "assets", "scripts", "layouts"] or sub.begins_with("."):
			continue
		_scan(dir.path_join(sub), depth + 1)
	for f in d.get_files():
		if f.ends_with(".tscn"):
			var p := dir.path_join(f)
			if FileAccess.get_file_as_string(p).contains("embers_world.gd") and not _worlds.has(p):
				_worlds.append(p)


# ---------------------------------------------------------------- saving
func _load() -> void:
	var c := ConfigFile.new()
	var ok := c.load(SAVE) == OK
	_server.text = str(Online.cfg.get("url", c.get_value("login", "server", "ws://127.0.0.1:7777") if ok else "ws://127.0.0.1:7777"))
	_account.text = str(Online.cfg.get("account", c.get_value("login", "account", "") if ok else ""))
	var w: String = str(Online.cfg.get("world", c.get_value("login", "world", "") if ok else ""))
	_world.select(maxi(0, _worlds.find(w)))
	if ok and c.get_value("login", "has_account", false) and not Online.cfg.has("register"):
		_set_mode(false)
	if _account.text != "":
		_password.grab_focus.call_deferred()
	else:
		_account.grab_focus.call_deferred()


func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("login", "server", _server.text.strip_edges())
	c.set_value("login", "account", _account.text.strip_edges())
	c.set_value("login", "world", _worlds[_world.selected])
	c.set_value("login", "has_account", true)
	c.save(SAVE)


# ---------------------------------------------------------------- go
func _submit() -> void:
	if _busy:
		return
	var url := _server.text.strip_edges()
	var acct := _account.text.strip_edges()
	var pw := _password.text
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		return _say("The server address starts with ws:// (for example ws://127.0.0.1:7777).", true)
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_]{3,20}$")
	if re.search(acct) == null:
		return _say("The account name is 3 to 20 letters, numbers or underscores.", true)
	if _register and pw.length() < 8:
		return _say("Pick a password of at least 8 characters.", true)
	if pw == "":
		return _say("Type your password.", true)
	_busy = true
	_save()
	var want: String = _worlds[_world.selected]
	Online.cfg = {"auto": true, "url": url, "account": acct, "password": pw, "register": _register,
		"class": "warrior", "world": want, "demo_done": true}
	_say("Connecting...", false)
	var loaded: String = str(main.world.get_meta("custom_world", ""))
	if want == loaded:
		main.online = Online.try_start(main)
		queue_free()
	else:
		# the world is built when the game starts, so a different world means starting again
		_say("Loading the world...", false)
		await get_tree().process_frame
		get_tree().reload_current_scene()
