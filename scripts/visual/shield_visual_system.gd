extends Node
class_name ShieldVisualSystem
## Visual effects for ship shields
## Animated ripple shader, transparency pulsation, impact effects

# =============================================================================
# CONFIGURATION
# =============================================================================

const SHIELD_FADE_TIME: float = 1.5  # Seconds to fade in/out
const SHIELD_PULSE_SPEED: float = 2.0  # Transparency pulse frequency
const SHIELD_PULSE_AMOUNT: float = 0.15  # Transparency pulse amplitude
const SHIELD_BASE_OPACITY: float = 0.3  # Base shield transparency
const IMPACT_RIPPLE_DURATION: float = 0.8  # Impact ripple effect duration

# =============================================================================
# STATE
# =============================================================================

var _enabled: bool = true
var _shield_mesh: MeshInstance3D = null
var _shield_material: ShaderMaterial = null
var _emitter_glow: OmniLight3D = null
var _ship: Node3D = null

var _shields_active: bool = false
var _shield_strength: float = 100.0
var _shield_power: float = 25.0
var _current_opacity: float = 0.0
var _pulse_time: float = 0.0

var _fade_tween: Tween = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_find_ship()
	_create_shield_sphere()
	_create_emitter_glow()

func _find_ship() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("get_ship"):
		_ship = parent.get_ship()
	if not _ship:
		_ship = _find_node_by_class("ShipController")

func _find_node_by_class(class_name_str: String) -> Node:
	var root: Node = get_tree().current_scene
	return _find_recursive(root, class_name_str)

func _find_recursive(node: Node, class_name_str: String) -> Node:
	var script: Script = node.get_script()
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result: Node = _find_recursive(child, class_name_str)
		if result:
			return result
	return null

# =============================================================================
# SHIELD SPHERE CREATION
# =============================================================================

func _create_shield_sphere() -> void:
	if not _ship:
		return

	# Create shield mesh
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.name = "ShieldSphere"

	# Create sphere mesh
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 15.0  # Adjust based on ship size
	sphere.height = 30.0
	sphere.radial_segments = 64
	sphere.rings = 32
	_shield_mesh.mesh = sphere

	# Create shader material
	_shield_material = ShaderMaterial.new()
	_shield_material.shader = _create_shield_shader()
	_shield_mesh.material_override = _shield_material

	# Set initial state (invisible)
	_shield_material.set_shader_parameter("opacity", 0.0)
	_shield_material.set_shader_parameter("ripple_intensity", 0.0)
	_shield_material.set_shader_parameter("shield_color", Color(0.3, 0.6, 1.0, 1.0))
	_shield_material.set_shader_parameter("noise_scale", 3.0)
	_shield_material.set_shader_parameter("noise_speed", 0.5)
	_shield_material.set_shader_parameter("fresnel_power", 2.0)

	# Add to ship
	_ship.add_child(_shield_mesh)
	_shield_mesh.position = Vector3.ZERO

func _create_shield_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

uniform vec4 shield_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.3;
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.0;
uniform float noise_scale : hint_range(1.0, 10.0) = 3.0;
uniform float noise_speed : hint_range(0.0, 2.0) = 0.5;
uniform float ripple_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ripple_origin = vec3(0.0, 0.0, 1.0);
uniform float ripple_time : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_offset : hint_range(0.0, 6.28) = 0.0;

// Simplex noise function
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
	const vec2 C = vec2(1.0/6.0, 1.0/3.0);
	const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
	vec3 i  = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy;
	vec3 x3 = x0 - D.yyy;
	i = mod289(i);
	vec4 p = permute(permute(permute(
		i.z + vec4(0.0, i1.z, i2.z, 1.0))
		+ i.y + vec4(0.0, i1.y, i2.y, 1.0))
		+ i.x + vec4(0.0, i1.x, i2.x, 1.0));
	float n_ = 0.142857142857;
	vec3 ns = n_ * D.wyz - D.xzx;
	vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
	vec4 x_ = floor(j * ns.z);
	vec4 y_ = floor(j - 7.0 * x_);
	vec4 x = x_ * ns.x + ns.yyyy;
	vec4 y = y_ * ns.x + ns.yyyy;
	vec4 h = 1.0 - abs(x) - abs(y);
	vec4 b0 = vec4(x.xy, y.xy);
	vec4 b1 = vec4(x.zw, y.zw);
	vec4 s0 = floor(b0) * 2.0 + 1.0;
	vec4 s1 = floor(b1) * 2.0 + 1.0;
	vec4 sh = -step(h, vec4(0.0));
	vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
	vec3 p0 = vec3(a0.xy, h.x);
	vec3 p1 = vec3(a0.zw, h.y);
	vec3 p2 = vec3(a1.xy, h.z);
	vec3 p3 = vec3(a1.zw, h.w);
	vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
	p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
	vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
	m = m * m;
	return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

void fragment() {
	// Fresnel effect for edge glow
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);

	// Animated noise for energy effect
	float noise = snoise(VERTEX * noise_scale + vec3(TIME * noise_speed));
	noise = noise * 0.5 + 0.5;

	// Transparency pulsation
	float pulse = sin(TIME * 2.0 + pulse_offset) * 0.15 + 1.0;

	// Impact ripple effect
	float ripple = 0.0;
	if (ripple_intensity > 0.0) {
		float dist = distance(normalize(VERTEX), normalize(ripple_origin));
		float ripple_wave = sin((dist - ripple_time * 3.0) * 20.0) * 0.5 + 0.5;
		ripple_wave *= smoothstep(0.0, 0.3, ripple_time) * smoothstep(1.0, 0.5, ripple_time);
		ripple = ripple_wave * ripple_intensity * (1.0 - dist);
	}

	// Combine effects
	float final_opacity = opacity * fresnel * pulse * (1.0 + noise * 0.3 + ripple);

	ALBEDO = shield_color.rgb * (1.0 + ripple * 2.0);
	ALPHA = clamp(final_opacity, 0.0, 1.0);
	EMISSION = shield_color.rgb * (fresnel * 0.5 + ripple);
}
"""
	return shader

# =============================================================================
# EMITTER GLOW
# =============================================================================

func _create_emitter_glow() -> void:
	if not _ship:
		return

	_emitter_glow = OmniLight3D.new()
	_emitter_glow.name = "ShieldEmitterGlow"
	_emitter_glow.light_color = Color(0.3, 0.6, 1.0)
	_emitter_glow.light_energy = 0.0
	_emitter_glow.omni_range = 20.0
	_emitter_glow.omni_attenuation = 1.5

	_ship.add_child(_emitter_glow)
	_emitter_glow.position = Vector3(0, 0, 10)  # Front of ship (deflector area)

# =============================================================================
# PROCESS
# =============================================================================

func _process(delta: float) -> void:
	if not _enabled or not _shield_material:
		return

	# Update pulse animation
	_pulse_time += delta * SHIELD_PULSE_SPEED
	if _shield_material:
		_shield_material.set_shader_parameter("pulse_offset", _pulse_time)

# =============================================================================
# PUBLIC API
# =============================================================================

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _shield_mesh:
		_shield_mesh.visible = enabled and _shields_active

func update_shields(strength: float, is_raised: bool) -> void:
	_shield_strength = strength
	var was_active: bool = _shields_active
	_shields_active = is_raised

	if is_raised and not was_active:
		_fade_shield_in()
	elif not is_raised and was_active:
		_fade_shield_out()

	# Update opacity based on strength
	if _shields_active:
		var strength_factor: float = strength / 100.0
		var target_opacity: float = SHIELD_BASE_OPACITY * strength_factor
		target_opacity *= (0.8 + (_shield_power / 25.0) * 0.2)  # Power affects opacity
		if _shield_material:
			_shield_material.set_shader_parameter("opacity", target_opacity * _current_opacity)

func update_power(shield_power: float) -> void:
	_shield_power = shield_power
	# Higher shield power = slightly more visible shields
	if _shields_active and _shield_material:
		var power_factor: float = 0.8 + (shield_power / 25.0) * 0.2
		var opacity: float = SHIELD_BASE_OPACITY * (_shield_strength / 100.0) * power_factor
		_shield_material.set_shader_parameter("opacity", opacity * _current_opacity)

func trigger_impact(impact_point: Vector3, intensity: float = 1.0) -> void:
	if not _enabled or not _shield_material:
		return

	# Set impact origin in local space
	if _ship:
		var local_point: Vector3 = _ship.to_local(impact_point).normalized()
		_shield_material.set_shader_parameter("ripple_origin", local_point)
	else:
		_shield_material.set_shader_parameter("ripple_origin", impact_point.normalized())

	_shield_material.set_shader_parameter("ripple_intensity", intensity)

	# Animate ripple
	var tween: Tween = create_tween()
	tween.tween_method(_set_ripple_time, 0.0, 1.0, IMPACT_RIPPLE_DURATION)
	tween.tween_callback(_end_ripple)

func _set_ripple_time(value: float) -> void:
	if _shield_material:
		_shield_material.set_shader_parameter("ripple_time", value)

func _end_ripple() -> void:
	if _shield_material:
		_shield_material.set_shader_parameter("ripple_intensity", 0.0)

# =============================================================================
# FADE EFFECTS
# =============================================================================

func _fade_shield_in() -> void:
	if _shield_mesh:
		_shield_mesh.visible = true

	if _fade_tween:
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_shield_opacity, 0.0, 1.0, SHIELD_FADE_TIME)

	# Fade in emitter glow
	if _emitter_glow:
		var glow_tween: Tween = create_tween()
		glow_tween.tween_property(_emitter_glow, "light_energy", 2.0, SHIELD_FADE_TIME)

func _fade_shield_out() -> void:
	if _fade_tween:
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_shield_opacity, _current_opacity, 0.0, SHIELD_FADE_TIME)
	_fade_tween.tween_callback(_hide_shield)

	# Fade out emitter glow
	if _emitter_glow:
		var glow_tween: Tween = create_tween()
		glow_tween.tween_property(_emitter_glow, "light_energy", 0.0, SHIELD_FADE_TIME)

func _set_shield_opacity(value: float) -> void:
	_current_opacity = value
	if _shield_material:
		var base_opacity: float = SHIELD_BASE_OPACITY * (_shield_strength / 100.0)
		_shield_material.set_shader_parameter("opacity", base_opacity * value)

func _hide_shield() -> void:
	if _shield_mesh:
		_shield_mesh.visible = false
