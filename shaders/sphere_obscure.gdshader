shader_type spatial;

// Obscure tribe: near-black sphere with a rotating crown of spikes near one
// pole (+Y) and a faint inner glow. The spike crown needs a HIGH subdivision
// mesh (128 radial / 64 rings) — on a low-poly sphere the crown reads as
// jagged clumps of triangles instead of pointed spikes, since each spike's
// tip and base both need enough vertices to actually taper.

uniform float spike_height_a : hint_range(0.0, 1.0) = 0.35;
uniform float spike_freq_a : hint_range(1.0, 20.0) = 4.5;
uniform float rotation_speed : hint_range(-2.0, 2.0) = 0.25;
uniform float crown_threshold : hint_range(0.0, 1.0) = 0.55;

uniform vec4 glow_color : source_color = vec4(0.10, 0.00, 0.02, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying float crown_glow_v;

void vertex() {
	vec3 vertex_dir = normalize(VERTEX);

	// Soft-edged band around the +Y pole so the crown reads as a localized
	// ring of spikes rather than covering the whole sphere.
	float crown_mask = smoothstep(crown_threshold, 1.0, vertex_dir.y);

	// Angle around the pole axis; rotating it (rather than rotating VERTEX
	// itself) keeps the crown's band shape fixed while the spike pattern
	// spins through it.
	float angle = atan(vertex_dir.z, vertex_dir.x) - TIME * rotation_speed;
	float spike_wave = sin(angle * spike_freq_a);
	// Clamp-then-power turns the smooth sine lobes into narrow pointed
	// peaks with flat gaps between them, so spike_freq_a reads as a count
	// of distinct spikes instead of a wavy ripple.
	float spike_pointy = pow(max(spike_wave, 0.0), 3.0);

	float displacement = crown_mask * spike_pointy * spike_height_a;
	VERTEX += NORMAL * displacement;

	crown_glow_v = crown_mask * (0.4 + 0.6 * spike_pointy);
}

void fragment() {
	ALBEDO = vec3(0.015, 0.01, 0.02);

	float pulse = sin(TIME * 0.6) * 0.5 + 0.5;
	float glow_strength = mix(0.5, 1.0, crown_glow_v) * mix(0.85, 1.15, pulse);
	EMISSION = glow_color.rgb * glow_strength;

	ROUGHNESS = roughness;
	METALLIC = metallic;
}
