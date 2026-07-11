shader_type spatial;

uniform vec3 dent_direction = vec3(0.0, 1.0, 0.0);
uniform float dent_radius : hint_range(0.0, 1.0) = 0.5;
uniform float min_depth : hint_range(0.0, 1.0) = 0.05;
uniform float max_depth : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.0;

uniform vec4 base_color : source_color = vec4(0.7, 0.75, 0.85, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;

varying float falloff_v;

float dent_falloff(vec3 vertex_dir, vec3 center_dir) {
	float closeness = dot(vertex_dir, center_dir);
	return smoothstep(1.0 - dent_radius, 1.0, closeness);
}

void vertex() {
	vec3 center_dir = normalize(dent_direction);
	vec3 vertex_dir = normalize(VERTEX);
	float falloff = dent_falloff(vertex_dir, center_dir);

	// sin() ranges -1..1; remap to 0..1 so it drives a depth *between*
	// min_depth and max_depth instead of also flipping the dent inside-out.
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float depth = mix(min_depth, max_depth, pulse);

	// Displace along the vertex's own NORMAL (not a fixed world axis) so the
	// crater sinks straight into the sphere's surface no matter which way
	// dent_direction points — the normal *is* the local "outward", so its
	// negation is always the correct "inward" for that point.
	VERTEX -= NORMAL * falloff * depth;

	falloff_v = falloff;
}

void fragment() {
	ALBEDO = base_color.rgb * mix(1.0, 0.75, falloff_v);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
