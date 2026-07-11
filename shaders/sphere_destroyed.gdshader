// ShaderMaterial needs transparency = ALPHA set in the scene (Material >
// Transparency > Alpha) or the discarded/faded fragments here won't actually
// read as gone.
shader_type spatial;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.45;
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.5, 1.0);
uniform float edge_width : hint_range(0.0, 0.5) = 0.08;
uniform float edge_glow_energy : hint_range(0.0, 8.0) = 3.0;

uniform vec4 base_color : source_color = vec4(0.08, 0.08, 0.1, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float noise_scale : hint_range(0.5, 20.0) = 4.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Trilinear value noise rather than raw per-fragment hash — a raw hash
// dissolves as uniform TV static, not the organic patches an erosion needs.
float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = hash(cell + vec3(0.0, 0.0, 0.0));
	float n100 = hash(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash(cell + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z);
}

void fragment() {
	float noise_value = value_noise(VERTEX * noise_scale);

	// Discard outright (not just ALPHA=0) so eroded patches also drop out of
	// depth/shadow, instead of leaving a ghost silhouette behind.
	if (noise_value < dissolve_amount) {
		discard;
	}

	// 1.0 right at the erosion boundary, fading to 0.0 across edge_width —
	// stays continuous as dissolve_amount sweeps either direction for the
	// reconstruct animation.
	float edge = 1.0 - smoothstep(dissolve_amount, dissolve_amount + edge_width, noise_value);

	ALBEDO = base_color.rgb;
	ALPHA = base_color.a;
	EMISSION = edge_color.rgb * edge * edge_glow_energy;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
