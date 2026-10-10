class_name DayNight
extends Node
## The living sky: a 12-minute day/night cycle with a custom sky (sun, moon, stars, drifting
## clouds), time-of-day lighting blended with each biome's mood, night lamps and windows,
## fire flicker, a little lantern on the player after dark, drifting weather and ambient
## particles (pollen, leaves, spores, snow, fireflies).

const DAY_SECONDS := 720.0
const START_TOD := 0.3          # new games begin on a bright morning

## time of day: 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
## [t, sky top, horizon, ambient colour, ambient energy, sun colour, sun strength,
##  fog tint, fog density x, exposure, cloud colour, star brightness]
const KEYS := [
	[0.00, Color("03060f"), Color("0c1a2a"), Color("4a6a90"), 0.30, Color("ffffff"), 0.0, Color("123038"), 1.9, 1.15, Color("1c2a40"), 1.0],
	[0.21, Color("141c3c"), Color("2c3a58"), Color("50628c"), 0.32, Color("ffffff"), 0.0, Color("2a3a50"), 2.0, 1.1, Color("3a4668"), 0.7],
	[0.26, Color("4a5f9e"), Color("f2a272"), Color("b0928e"), 0.42, Color("ffb070"), 0.55, Color("ffb894"), 1.7, 1.0, Color("ffc09a"), 0.1],
	[0.33, Color("54789e"), Color("c0c8d0"), Color("b4c4de"), 0.24, Color("ffe0bc"), 0.62, Color("e0e6ee"), 2.4, 0.76, Color("e8ecf2"), 0.0],
	[0.50, Color("4a6688"), Color("b0bfc6"), Color("c0d0e8"), 0.22, Color("fff0d8"), 0.6, Color("d0dae4"), 2.4, 0.66, Color("e0e6ec"), 0.0],
	[0.67, Color("4f729c"), Color("c8c4b8"), Color("c8cce0"), 0.22, Color("ffdcae"), 0.6, Color("f0e4d4"), 2.0, 0.76, Color("f2e8da"), 0.0],
	[0.74, Color("404f8c"), Color("ff8a50"), Color("b88888"), 0.38, Color("ff8040"), 0.62, Color("ffa070"), 1.45, 1.0, Color("ff9a70"), 0.05],
	[0.80, Color("182248"), Color("5a4466"), Color("5a68a0"), 0.32, Color("ff6030"), 0.12, Color("4a4a6a"), 1.5, 1.08, Color("584a78"), 0.5],
	[0.88, Color("03060f"), Color("0c1a2a"), Color("4a6a90"), 0.30, Color("ffffff"), 0.0, Color("123038"), 1.9, 1.15, Color("1c2a40"), 1.0],
	[1.00, Color("03060f"), Color("0c1a2a"), Color("4a6a90"), 0.30, Color("ffffff"), 0.0, Color("123038"), 1.9, 1.15, Color("1c2a40"), 1.0],
]

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_col : source_color = vec3(0.3, 0.45, 0.7);
uniform vec3 hor_col : source_color = vec3(0.8, 0.85, 0.9);
uniform vec3 bot_col : source_color = vec3(0.2, 0.27, 0.35);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 cloud_col : source_color = vec3(1.0);
uniform float sun_vis = 1.0;
uniform float star_vis = 0.0;
uniform float cloud_th = 0.58;
uniform vec2 star_off = vec2(0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}
void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(hor_col, top_col, pow(clamp(h, 0.0, 1.0), 0.5));
	} else {
		col = mix(hor_col, bot_col, pow(clamp(-h * 2.0, 0.0, 1.0), 0.6));
	}
	// stars
	if (h > 0.0 && star_vis > 0.01) {
		vec2 p = d.xz / (h + 0.35) * 55.0 + star_off;
		vec2 ip = floor(p);
		vec2 fp = fract(p) - 0.5;
		float r = hash(ip);
		vec2 off = (vec2(hash(ip + 3.1), hash(ip + 7.7)) - 0.5) * 0.5;
		float star = step(0.972, r) * smoothstep(0.3, 0.0, length(fp - off));
		star *= 0.65 + 0.35 * sin(TIME * 2.2 + r * 60.0);
		col += vec3(0.85, 0.92, 1.0) * star * star_vis * smoothstep(0.0, 0.2, h) * 1.4;
	}
	// sun
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_col * (pow(sd, 6.0) * 0.16 + pow(sd, 48.0) * 0.28) * sun_vis;
	col = mix(col, vec3(1.0, 0.96, 0.82) * 2.2, smoothstep(0.99935, 0.99965, sd) * sun_vis * step(-0.02, h));
	// moon
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	vec3 mcol = vec3(0.78, 0.86, 1.0);
	col += mcol * pow(md, 40.0) * 0.16 * step(0.0, moon_dir.y);
	float disc = smoothstep(0.9990, 0.9993, md) * step(-0.02, h) * step(0.0, moon_dir.y);
	vec3 mooncol = mcol * (1.5 - 0.35 * noise(d.xz * 90.0 + d.y * 60.0));
	col = mix(col, mooncol, disc);
	// clouds
	if (h > 0.01) {
		vec2 uv = d.xz / (h + 0.2) * 0.9 + vec2(TIME * 0.012, TIME * 0.004);
		float n = fbm(uv);
		float c = smoothstep(cloud_th, cloud_th + 0.12, n);
		float shade = smoothstep(cloud_th + 0.1, cloud_th + 0.3, n);
		vec3 cc = mix(cloud_col, cloud_col * 0.62 + hor_col * 0.15, shade);
		col = mix(col, cc, c * smoothstep(0.01, 0.2, h) * 0.9);
	}
	COLOR = col;
}
"""

var tod := START_TOD
var biome := 0
var cave := false               # underground: no sun, a dim cold ambience, the lantern always lit
var frozen := false             # true during the tutorial camp: it stays a nice morning
var speed := 1.0

var night := 0.0                # 0 = full day, 1 = deep night
var sun_up := 1.0               # 0..1 how high the sun is

var _env: Environment
var _sun: DirectionalLight3D
var _world: World
var _player: Player
var _atmos: Array = []
var _sky_mat: ShaderMaterial
var _fog_col := Color.WHITE
var _fog_den := 0.004
var _sun_col := Color.WHITE
var _sun_pow := 1.0
var _lamps: Array = []
var _flickers: Array = []
var _scan_t := 0.0
var _t := 0.0
var _lantern: OmniLight3D
var _motes: GPUParticles3D
var _flies: GPUParticles3D
var _mote_biome := -1
var _glow_mat: ShaderMaterial
var _vig: ColorRect

# ---- weather: a slowly shifting state, eased so nothing pops
const WX := {
	"clear": {"over": 0.0, "fog": 0.0, "rain": 0.0, "storm": 0.0},
	"overcast": {"over": 0.85, "fog": 0.0, "rain": 0.0, "storm": 0.0},
	"fog": {"over": 0.35, "fog": 1.0, "rain": 0.0, "storm": 0.0},
	"rain": {"over": 0.8, "fog": 0.1, "rain": 0.7, "storm": 0.0},
	"storm": {"over": 1.0, "fog": 0.15, "rain": 1.0, "storm": 1.0},
}
## chance weights per biome (plains, forest, bog, mountains)
const WX_ODDS := [
	{"clear": 9, "overcast": 2, "fog": 1, "rain": 1},
	{"clear": 6, "overcast": 3, "fog": 3, "rain": 1, "storm": 1},
	{"clear": 3, "overcast": 3, "fog": 5, "rain": 2, "storm": 1},
	{"clear": 6, "overcast": 3, "fog": 2, "rain": 2, "storm": 1},
]
var weather := "clear"
var wx_over := 0.0
var wx_fog := 0.0
var wx_rain := 0.0
var wx_storm := 0.0
var _wx_timer := 150.0
var _flash := 0.0
var _flash2 := 0.0
var _strike_in := 8.0
var _thunder_in := -1.0
var _rain_fx: GPUParticles3D
var _snow_fx: GPUParticles3D
var _rain_snd: AudioStreamPlayer
var _wind := 1.0


func setup(env: Environment, sun: DirectionalLight3D, world: World, player: Player, atmos: Array) -> void:
	_env = env
	_sun = sun
	_world = world
	_player = player
	_atmos = atmos
	_fog_col = atmos[0][0]
	_fog_den = atmos[0][1]
	_sun_col = atmos[0][2]
	_sun_pow = atmos[0][3]
	var sh := Shader.new()
	sh.code = SKY_SHADER
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color("ffd49a")
	_lantern.omni_range = 7.5
	_lantern.light_energy = 0.0
	_lantern.omni_attenuation = 1.4
	_lantern.position = Vector3(0, 2.4, 0)
	_lantern.shadow_enabled = false
	player.add_child(_lantern)
	World.ensure_wind()
	_build_particles()
	_build_weather_fx()
	_build_vignette()
	_glow_mat = TownKit.glow_material()
	snap()


## jump straight to the current time (title screen, tests, loading a save)
func snap() -> void:
	_apply(0.0, true)


func _process(delta: float) -> void:
	_t += delta
	if not frozen:
		tod = fposmod(tod + delta * speed / DAY_SECONDS, 1.0)
	_tick_weather(delta)
	_apply(delta, false)


# ------------------------------------------------------------------ keyframes
func _key(i: int, idx: int) -> Variant:
	return (KEYS[i] as Array)[idx]


func _sample() -> Array:
	var i := 0
	while i < KEYS.size() - 2 and tod >= float(_key(i + 1, 0)):
		i += 1
	var t0 := float(_key(i, 0))
	var t1 := float(_key(i + 1, 0))
	var f := clampf((tod - t0) / (t1 - t0), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var out: Array = []
	for k in range(1, 12):
		var a: Variant = _key(i, k)
		var b: Variant = _key(i + 1, k)
		if a is Color:
			out.append((a as Color).lerp(b as Color, f))
		else:
			out.append(lerpf(float(a), float(b), f))
	return out


func _apply(delta: float, instant: bool) -> void:
	var s := _sample()
	var a: float = (tod - 0.25) * TAU
	var sun_to := Vector3(cos(a) * 0.85, sin(a), 0.5).normalized()
	var moon_to := Vector3(-sun_to.x, -sun_to.y, sun_to.z * 0.6 + 0.25).normalized()
	var elev := sun_to.y
	night = 1.0 - smoothstep(-0.12, 0.14, elev)
	sun_up = smoothstep(0.0, 0.18, elev)

	# slow weather: some stretches are overcast and misty
	var wx := sin(_t * 0.011 + 1.3) + 0.5 * sin(_t * 0.027 + 4.0)
	var overcast := maxf(smoothstep(0.45, 1.4, wx) * 0.5, wx_over)
	var mist := 1.0 + overcast * 0.8 + wx_fog * 3.0 + wx_rain * 0.6

	# biome mood, eased
	var ba: Array = _atmos[clampi(biome, 0, _atmos.size() - 1)]
	var k := 1.0 if instant else (1.0 - exp(-delta * 1.5))
	_fog_col = _fog_col.lerp(ba[0], k)
	_fog_den = lerpf(_fog_den, float(ba[1]), k)
	_sun_col = _sun_col.lerp(ba[2], k)
	_sun_pow = lerpf(_sun_pow, float(ba[3]), k)

	var tint: Color = s[6]
	var fog := Color(_fog_col.r * tint.r, _fog_col.g * tint.g, _fog_col.b * tint.b)
	fog = fog.lerp(Color(fog.r * 0.55 + 0.05, fog.g * 0.58 + 0.05, fog.b * 0.62 + 0.07), overcast * 0.5)
	fog = fog.lerp(Color(0.62, 0.66, 0.7) * (1.0 - night * 0.85), clampf(wx_fog * 0.55, 0.0, 0.6))
	_env.fog_light_color = fog
	_env.fog_density = _fog_den * float(s[7]) * mist
	var dawn := smoothstep(0.18, 0.27, tod) * (1.0 - smoothstep(0.27, 0.42, tod))
	_env.fog_height = 2.5
	if cave:
		_env.fog_light_color = Color(0.03, 0.04, 0.05)
		_env.fog_density = 0.014
	_env.fog_height_density = lerpf(0.03, 0.2, clampf(night + dawn, 0.0, 1.0)) * mist * (1.0 + wx_fog)
	if cave:
		_env.fog_height_density = 0.0
	if _vig:
		var vm := _vig.material as ShaderMaterial
		vm.set_shader_parameter("strength", lerpf(0.4, 0.7, night))
		vm.set_shader_parameter("tint", Color(0.02, 0.04, 0.07).lerp(Color(0.04, 0.03, 0.02), 1.0 - night))
	_env.ambient_light_color = s[2]
	_env.ambient_light_energy = float(s[3])
	if cave:
		_env.ambient_light_color = Color(0.6, 0.65, 0.8)
		_env.ambient_light_energy = 1.15
	_env.tonemap_exposure = float(s[8]) * (1.0 - wx_rain * 0.1 - wx_storm * 0.06)
	_env.glow_intensity = lerpf(0.4, 1.0, night)
	_env.adjustment_saturation = lerpf(0.9, 0.58, night) - overcast * 0.1
	if _flash > 0.0 or _flash2 > 0.0:
		_env.ambient_light_energy += maxf(_flash, _flash2) * 1.8

	# one directional light plays the sun by day and the moon by night
	var sc: Color = s[4]
	var light_col := Color(_sun_col.r * sc.r, _sun_col.g * sc.g, _sun_col.b * sc.b)
	var sun_e := float(s[5]) * _sun_pow * smoothstep(0.0, 0.1, elev) * (1.0 - overcast * 0.55)
	var moon_e := 0.24 * smoothstep(0.0, -0.12, elev) * (1.0 - overcast * 0.4)
	if elev > 0.0:
		_sun.basis = Basis.looking_at(-sun_to, Vector3.UP)
		_sun.light_color = light_col
		_sun.light_energy = sun_e
	else:
		_sun.basis = Basis.looking_at(-moon_to, Vector3.UP)
		_sun.light_color = Color("86a4e0")
		_sun.light_energy = moon_e
	_sun.visible = _sun.light_energy > 0.01 and not cave

	# sky
	var hor: Color = (s[1] as Color).lerp(fog, 0.35)
	_sky_mat.set_shader_parameter("top_col", s[0])
	_sky_mat.set_shader_parameter("hor_col", hor)
	_sky_mat.set_shader_parameter("bot_col", (s[0] as Color).lerp(hor, 0.5).darkened(0.4))
	_sky_mat.set_shader_parameter("sun_dir", sun_to)
	_sky_mat.set_shader_parameter("moon_dir", moon_to)
	_sky_mat.set_shader_parameter("sun_col", light_col.lerp(Color.WHITE, 0.2))
	_sky_mat.set_shader_parameter("sun_vis", smoothstep(-0.25, 0.1, elev) * (1.0 - overcast * 0.6))
	_sky_mat.set_shader_parameter("star_vis", float(s[10]) * (1.0 - overcast * 0.8))
	_sky_mat.set_shader_parameter("cloud_col", (s[9] as Color).darkened(wx_rain * 0.25 + wx_storm * 0.25))
	_sky_mat.set_shader_parameter("cloud_th", 0.6 - overcast * 0.18 - 0.04 * sin(_t * 0.02))
	_sky_mat.set_shader_parameter("star_off", Vector2(tod * 40.0, tod * 17.0))

	# water, windows
	if _world and _world.water_mat:
		_world.water_mat.set_shader_parameter("sky_col", hor)
		_world.water_mat.set_shader_parameter("night", night)
	if _glow_mat:
		_glow_mat.set_shader_parameter("glow", lerpf(0.12, 2.0, night))

	_tick_lights(delta)
	_tick_particles()


func _tick_lights(delta: float) -> void:
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 2.5
		_lamps = get_tree().get_nodes_in_group("lamp")
		_flickers = get_tree().get_nodes_in_group("flicker")
	var on := night > 0.03
	for n in _lamps:
		if not is_instance_valid(n):
			continue
		var l := n as OmniLight3D
		l.visible = on
		if on:
			l.light_energy = float(l.get_meta("base", 1.1)) * 2.0 * night * (1.0 + 0.06 * sin(_t * 5.0 + l.position.x))
	for n in _flickers:
		if not is_instance_valid(n):
			continue
		var l := n as OmniLight3D
		var base := float(l.get_meta("base", 1.2))
		l.light_energy = base * (1.0 + night * 1.2) * (1.0 + 0.16 * sin(_t * 9.0 + l.position.x * 3.0) + 0.1 * sin(_t * 17.0 + l.position.z * 5.0))
	if is_instance_valid(_lantern):
		_lantern.light_energy = 0.85 * (1.0 if cave else night)
		_lantern.visible = cave or night > 0.03


# ------------------------------------------------------------------ particles
func _mote_mat(col: Color, hdr: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(col.r * hdr, col.g * hdr, col.b * hdr, 1.0)
	m.disable_receive_shadows = true
	return m


func _fade_ramp(peak: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, peak), Color(1, 1, 1, peak), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _emitter(size: float, amount: int, life: float, mat: StandardMaterial3D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	p.draw_pass_1 = q
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -12, -30), Vector3(60, 28, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	add_child(p)
	return p


func _build_particles() -> void:
	_motes = _emitter(0.065, 140, 9.0, _mote_mat(Color.WHITE, 1.0))
	_flies = _emitter(0.11, 100, 7.0, _mote_mat(Color("9affc8"), 2.4))
	var fm := ParticleProcessMaterial.new()
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fm.emission_box_extents = Vector3(20, 2.0, 20)
	fm.direction = Vector3(0, 1, 0)
	fm.spread = 180.0
	fm.initial_velocity_min = 0.1
	fm.initial_velocity_max = 0.5
	fm.gravity = Vector3.ZERO
	fm.turbulence_enabled = true
	fm.turbulence_noise_strength = 1.4
	fm.turbulence_noise_scale = 2.0
	fm.turbulence_influence_min = 0.05
	fm.turbulence_influence_max = 0.15
	fm.scale_min = 0.6
	fm.scale_max = 1.3
	fm.color_ramp = _fade_ramp(1.0)
	_flies.process_material = fm


func _set_motes(b: int) -> void:
	_mote_biome = b
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 1.0, 24)
	pm.color_ramp = _fade_ramp(0.8)
	var mat := _motes.draw_pass_1.material as StandardMaterial3D
	match b:
		1:   # Thornwood: falling leaves
			mat.albedo_color = Color("c8a040")
			pm.direction = Vector3(0.4, -1, 0.2)
			pm.spread = 30.0
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.6
			pm.gravity = Vector3(0.15, -0.35, 0.05)
			pm.scale_min = 1.2
			pm.scale_max = 2.2
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.8
			pm.turbulence_influence_min = 0.05
			pm.turbulence_influence_max = 0.2
			pm.emission_shape_offset = Vector3(0, 7, 0)
		2:   # The Mire: drifting spores
			mat.albedo_color = Color("b8d070")
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 60.0
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.25
			pm.gravity = Vector3(0, 0.02, 0)
			pm.scale_min = 0.8
			pm.scale_max = 1.8
			pm.emission_shape_offset = Vector3(0, 1.5, 0)
		3:   # Frostspine: snow
			mat.albedo_color = Color("ffffff")
			pm.direction = Vector3(0.3, -1, 0.1)
			pm.spread = 15.0
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 1.2
			pm.gravity = Vector3(0.4, -0.5, 0.1)
			pm.scale_min = 0.8
			pm.scale_max = 1.6
			pm.emission_shape_offset = Vector3(0, 8, 0)
		_:   # meadow / shore: pollen and dust motes in the sunlight
			mat.albedo_color = Color("fff0b0")
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 90.0
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3(0.05, 0.01, 0.0)
			pm.scale_min = 0.6
			pm.scale_max = 1.2
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			pm.turbulence_influence_min = 0.03
			pm.turbulence_influence_max = 0.1
			pm.emission_shape_offset = Vector3(0, 2.5, 0)
	_motes.process_material = pm


func _tick_particles() -> void:
	if _player == null or _motes == null:
		return
	var p := _player.global_position
	_motes.global_position = Vector3(p.x, p.y, p.z)
	_flies.global_position = Vector3(p.x, p.y + 0.6, p.z)
	if biome != _mote_biome:
		_set_motes(biome)
	# leaves and snow fall any time; pollen and spores only in daylight
	var day_only := biome != 1 and biome != 3
	var motes_on := (sun_up > 0.1) if day_only else true
	if biome == 2:
		motes_on = true
	_motes.emitting = motes_on
	_flies.emitting = night > 0.35 and biome != 3


func weather_name() -> String:
	if cave or weather == "clear":
		return ""
	var snowy := biome == 3
	match weather:
		"overcast": return "OVERCAST"
		"fog": return "FOG"
		"rain": return "SNOW" if snowy else "RAIN"
		"storm": return "BLIZZARD" if snowy else "STORM"
	return ""


## jump to a weather state at once (tests, debugging)
func force_weather(kind: String) -> void:
	weather = kind
	var t: Dictionary = WX[kind]
	wx_over = t["over"]
	wx_fog = t["fog"]
	wx_rain = t["rain"]
	wx_storm = t["storm"]
	_wx_timer = 200.0


func _pick_weather() -> String:
	var odds: Dictionary = WX_ODDS[clampi(biome, 0, WX_ODDS.size() - 1)]
	var total := 0
	for k: String in odds:
		if k != weather:
			total += int(odds[k])
	var r := randi() % maxi(total, 1)
	for k: String in odds:
		if k == weather:
			continue
		r -= int(odds[k])
		if r < 0:
			return k
	return "clear"


func _tick_weather(delta: float) -> void:
	var calm := frozen or cave
	if calm:
		if weather != "clear":
			weather = "clear"
	else:
		_wx_timer -= delta
		if _wx_timer <= 0.0:
			weather = _pick_weather()
			_wx_timer = randf_range(110.0, 260.0)
	var t: Dictionary = WX[weather]
	var k := 1.0 - exp(-delta * (0.5 if calm else 0.06))
	wx_over = lerpf(wx_over, float(t["over"]), k)
	wx_fog = lerpf(wx_fog, float(t["fog"]), k)
	wx_rain = lerpf(wx_rain, float(t["rain"]), k)
	wx_storm = lerpf(wx_storm, float(t["storm"]), k)
	# gusts
	var gust := 0.5 + 0.5 * sin(_t * 0.7) * sin(_t * 0.31 + 1.0)
	_wind = 1.0 + wx_over * 0.4 + wx_rain * 0.8 + wx_storm * 1.4 + gust * (0.2 + wx_rain * 0.6)
	RenderingServer.global_shader_parameter_set("wind", _wind)
	# lightning in storms
	_flash = maxf(0.0, _flash - delta * 4.0)
	_flash2 = maxf(0.0, _flash2 - delta * 3.0)
	if wx_storm > 0.6 and not cave:
		_strike_in -= delta
		if _strike_in <= 0.0:
			_strike_in = randf_range(7.0, 20.0)
			_flash = 1.0
			_flash2 = 0.0
			get_tree().create_timer(0.18).timeout.connect(func() -> void: _flash2 = 0.7)
			_thunder_in = randf_range(0.6, 2.8)
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in < 0.0:
			Sfx.play("explosion", Vector3.INF, -12.0, 0.25)
	_tick_weather_fx()


func _build_weather_fx() -> void:
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.74, 0.82, 0.94, 0.55)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rq := QuadMesh.new()
	rq.size = Vector2(0.018, 0.55)
	rq.material = rm
	_rain_fx = GPUParticles3D.new()
	_rain_fx.draw_pass_1 = rq
	_rain_fx.amount = 1800
	_rain_fx.lifetime = 0.8
	_rain_fx.preprocess = 0.8
	_rain_fx.local_coords = false
	_rain_fx.visibility_aabb = AABB(Vector3(-24, -6, -24), Vector3(48, 30, 48))
	_rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15, 0.5, 15)
	pm.direction = Vector3(0.12, -1, 0.04)
	pm.spread = 2.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3.ZERO
	_rain_fx.process_material = pm
	_rain_fx.emitting = false
	add_child(_rain_fx)

	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var sq := QuadMesh.new()
	sq.size = Vector2(0.085, 0.085)
	sq.material = sm
	_snow_fx = GPUParticles3D.new()
	_snow_fx.draw_pass_1 = sq
	_snow_fx.amount = 2400
	_snow_fx.lifetime = 7.0
	_snow_fx.preprocess = 7.0
	_snow_fx.local_coords = false
	_snow_fx.visibility_aabb = AABB(Vector3(-24, -6, -24), Vector3(48, 30, 48))
	_snow_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(15, 0.5, 15)
	sp.direction = Vector3(0.3, -1, 0.1)
	sp.spread = 18.0
	sp.initial_velocity_min = 1.6
	sp.initial_velocity_max = 2.8
	sp.gravity = Vector3(0.6, -0.3, 0.2)
	sp.turbulence_enabled = true
	sp.turbulence_noise_strength = 1.2
	sp.turbulence_influence_min = 0.05
	sp.turbulence_influence_max = 0.18
	_snow_fx.process_material = sp
	_snow_fx.emitting = false
	add_child(_snow_fx)

	# rain hiss: a short loop of filtered noise built in code, so there is no audio file to ship
	var rate := 22050
	var n := rate * 2
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in n:
		lp = lp * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
		var v := clampi(int(lp * 9000.0), -32000, 32000)
		buf.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = buf
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	_rain_snd = AudioStreamPlayer.new()
	_rain_snd.stream = st
	_rain_snd.bus = "SFX"
	_rain_snd.volume_db = -80.0
	add_child(_rain_snd)
	_rain_snd.play()


func _tick_weather_fx() -> void:
	if _rain_fx == null or _player == null:
		return
	var p := _player.global_position
	var snowy := biome == 3
	var amt := 0.0 if cave else wx_rain
	_rain_fx.global_position = p + Vector3(0, 13, 0)
	_snow_fx.global_position = p + Vector3(0, 11, 0)
	_rain_fx.emitting = amt > 0.03 and not snowy
	_rain_fx.amount_ratio = clampf(amt, 0.05, 1.0)
	_snow_fx.emitting = amt > 0.03 and snowy
	_snow_fx.amount_ratio = clampf(amt, 0.05, 1.0)
	if _rain_snd:
		var vol := -80.0 if (amt < 0.03 or snowy) else lerpf(-34.0, -17.0, amt)
		_rain_snd.volume_db = lerpf(_rain_snd.volume_db, vol, 0.08)


func _build_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -1
	add_child(cl)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float strength = 0.4;\nuniform vec3 tint : source_color = vec3(0.0);\nvoid fragment() {\n\tvec2 uv = UV - 0.5;\n\tfloat v = smoothstep(0.3, 0.85, length(uv * vec2(1.0, 0.9)));\n\tCOLOR = vec4(tint, v * strength);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	_vig = ColorRect.new()
	_vig.material = m
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_vig)
