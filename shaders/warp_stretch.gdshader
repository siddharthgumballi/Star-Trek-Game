shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// TNG Warp stretch shader - stretches the ship mesh along forward axis
// Creates the iconic "stretch and snap" effect when entering warp
// Applied as material_overlay to preserve original textures

uniform float stretch_amount : hint_range(-0.1, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.5, 0.7, 1.0, 0.15);
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;

// Warp field distortion
uniform float field_distortion : hint_range(0.0, 0.1) = 0.02;

void vertex() {
	// Get the local Z position (forward axis)
	float z_pos = VERTEX.z;

	// Stretch vertices along Z axis (forward)
	// Vertices further from center stretch more - creates elongation effect
	float stretch_factor = abs(z_pos) * stretch_amount;
	VERTEX.z += stretch_factor * sign(z_pos);

	// Slight X/Y compression during stretch for "squeeze then snap" effect
	// More compression at higher stretch values
	float compression = 1.0 - (abs(stretch_amount) * 0.15);
	VERTEX.x *= compression;
	VERTEX.y *= compression;

	// Add subtle warp field distortion when glow is active
	if (glow_intensity > 0.0) {
		float wave = sin(z_pos * 0.5 + TIME * 3.0) * field_distortion * glow_intensity;
		VERTEX.x += wave;
		VERTEX.y += wave * 0.5;
	}
}

void fragment() {
	// Blue warp field glow effect
	// Only visible when glow_intensity > 0

	// Fresnel effect - glow stronger at edges
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.0);

	// Combine glow with fresnel for edge glow effect
	float glow = fresnel * glow_intensity;

	ALBEDO = glow_color.rgb * glow;
	ALPHA = glow * glow_color.a;

	// Add emission for the glow
	EMISSION = glow_color.rgb * glow * 2.0;
}
