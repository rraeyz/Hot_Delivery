class_name Look
extends RefCounted
## Visual style: environment/lighting per time of day, and world-space procedural materials.
## Everything is generated (no texture files), so it stays license-free and tiny.

const TODS := {
	# sun pitch/yaw (deg), sun color, sun energy, sky top, horizon, ambient energy, night factor
	"morning": [-22.0, 60.0, "#ffd6a5", 1.0, "#8ecae6", "#ffe5d9", 0.45, 0.0],
	"noon": [-58.0, 35.0, "#fff8ee", 1.25, "#4ea8de", "#cde7f7", 0.5, 0.0],
	"sunset": [-9.0, -60.0, "#ff8c42", 1.1, "#3d5a80", "#ffb07c", 0.4, 0.15],
	"night": [-40.0, 120.0, "#9db4ff", 0.18, "#0b1026", "#26305a", 0.25, 1.0],
}

const ROAD_SHADER := """
shader_type spatial;
uniform vec3 tint : source_color = vec3(0.19, 0.2, 0.22);
uniform float wet = 0.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float n = noise(p * 1.7) * 0.5 + noise(p * 7.0) * 0.3 + hash(floor(p * 40.0)) * 0.2;
	float patch = smoothstep(0.55, 0.6, noise(p * 0.08));
	vec3 col = tint * (0.8 + 0.4 * n) * (1.0 - patch * 0.15);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.25, wet * (0.6 + 0.4 * noise(p * 0.5)));
	float e = 0.02;
	float nx = noise((p + vec2(e, 0)) * 7.0) - noise((p - vec2(e, 0)) * 7.0);
	float nz = noise((p + vec2(0, e)) * 7.0) - noise((p - vec2(0, e)) * 7.0);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(nx * 1.5, 0.0, nz * 1.5, 0.0)).xyz);
}
"""

const TILE_SHADER := """
shader_type spatial;
uniform vec3 tint : source_color = vec3(0.72, 0.69, 0.65);
uniform float tile = 1.2;
uniform float grass = 0.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz / tile;
	vec2 g = fract(p);
	float joint = 1.0 - step(0.04, g.x) * step(0.04, g.y);
	float h = hash(floor(p));
	vec3 col = tint * (0.88 + 0.16 * h);
	if (grass > 0.5) {
		float b = hash(floor(wpos.xz * 9.0));
		col = tint * (0.75 + 0.35 * b);
		joint = 0.0;
	}
	if (NORMAL.y < 0.5) { joint = 0.0; col *= 0.85; }
	ALBEDO = mix(col, col * 0.55, joint);
	ROUGHNESS = 0.85;
}
"""

const BUILDING_SHADER := """
shader_type spatial;
uniform vec3 base_color : source_color;
uniform float night = 0.0;
uniform float seed = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	if (abs(wnorm.y) > 0.5) {
		vec2 g = fract(wpos.xz / 2.0);
		ALBEDO = base_color * 0.55 * (0.9 + 0.1 * step(0.5, g.x));
		ROUGHNESS = 0.95;
	} else {
		vec2 c = abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xy;
		vec2 cell = floor(c / vec2(2.6, 3.0));
		vec2 g = fract(c / vec2(2.6, 3.0));
		float frame = step(0.18, g.x) * step(g.x, 0.82) * step(0.25, g.y) * step(g.y, 0.85);
		float glass = step(0.22, g.x) * step(g.x, 0.78) * step(0.29, g.y) * step(g.y, 0.81);
		float upper = step(3.2, wpos.y);
		frame *= upper; glass *= upper;
		float sill = step(0.2, g.y) * step(g.y, 0.25) * step(0.15, g.x) * step(g.x, 0.85) * upper;
		float band = step(0.96, fract(wpos.y / 3.0));
		float shop = (1.0 - upper) * step(0.6, wpos.y) * step(wpos.y, 2.7) * step(0.08, fract(c.x / 4.0)) * step(fract(c.x / 4.0), 0.92);
		float brick = step(0.5, fract(c.y * 3.0 + step(0.5, fract(c.x * 1.5)) * 0.5)) * 0.04;
		vec3 wall = base_color * (0.95 - brick) * (1.0 - band * 0.15);
		vec3 frame_col = vec3(0.93);
		float lit = step(0.55, hash(cell)) * night;
		vec3 glass_col = mix(vec3(0.45, 0.62, 0.78), vec3(1.0, 0.82, 0.5), lit);
		vec3 col = mix(wall, frame_col, frame - glass + sill);
		col = mix(col, glass_col, max(glass, shop * 0.9));
		ALBEDO = col;
		ROUGHNESS = mix(0.9, 0.08, max(glass, shop));
		METALLIC = max(glass, shop) * 0.3;
		EMISSION = glass_col * max(glass * lit, shop * night) * 1.6;
	}
}
"""

static var _shaders := {}


static func shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


static func road_mat(wet: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(ROAD_SHADER)
	m.set_shader_parameter("wet", 1.0 if wet else 0.0)
	return m


static func tile_mat(c: Color, grass := false, tile := 1.2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(TILE_SHADER)
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("grass", 1.0 if grass else 0.0)
	m.set_shader_parameter("tile", tile)
	return m


static func building_mat(c: Color, night: float, seed_value: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(BUILDING_SHADER)
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("night", night)
	m.set_shader_parameter("seed", seed_value)
	return m


## Builds sky, sun and post-processing. Returns {env, sun, night}.
static func environment(parent: Node, tod: String, theme: Dictionary, chaos: Array) -> Dictionary:
	var d: Array = TODS[tod]
	var q := int(Game.settings.get("quality", 2))
	var rainy := "rain" in chaos
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(d[4]) if tod != "noon" else Color(theme.sky)
	sm.sky_horizon_color = Color(d[5])
	sm.ground_horizon_color = Color(d[5])
	sm.ground_bottom_color = Color(d[5]).darkened(0.6)
	sm.sun_angle_max = 20.0
	sm.sky_curve = 0.12
	if rainy:
		sm.sky_top_color = sm.sky_top_color.lerp(Color("#5c677d"), 0.7)
		sm.sky_horizon_color = sm.sky_horizon_color.lerp(Color("#979dac"), 0.7)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = d[6] * (1.2 if rainy else 1.0)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX if q > 0 else Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5 if tod == "night" else 0.25
	env.glow_bloom = 0.05
	if q >= 1:
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.6
	if q >= 2:
		env.ssil_enabled = true
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.004 if tod != "night" else 0.01
		env.volumetric_fog_albedo = Color(d[5])
		env.volumetric_fog_anisotropy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(d[5])
	env.fog_density = 0.002
	env.fog_aerial_perspective = 0.4
	if "fog" in chaos:
		env.fog_density = 0.035
		env.fog_sky_affect = 0.6
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(d[0]), deg_to_rad(d[1]), 0)
	sun.light_color = Color(d[2])
	sun.light_energy = d[3] * (0.5 if rainy else 1.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 90.0 if q >= 2 else 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 1 else DirectionalLight3D.SHADOW_ORTHOGONAL
	parent.add_child(sun)
	return {"env": env, "sun": sun, "night": float(d[7])}
