shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.70, 0.04, 0.10, 1.0);
uniform vec4 rim_color : source_color = vec4(1.00, 0.35, 0.45, 1.0);
uniform vec4 ring_color : source_color = vec4(1.00, 0.65, 0.75, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.8;

varying vec3 local_dir;

void vertex() {
	local_dir = normalize(VERTEX);
}

float rim_fresnel(vec3 normal, vec3 view) {
	float fresnel = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 3.0);
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	return fresnel * mix(0.5, 1.0, pulse);
}

// A great circle is the plane through the origin perpendicular to `axis`;
// `dir` sits on it when dot(dir, axis) == 0. Repeating that test at several
// offsets and sliding the offset with TIME turns one ring into a band of
// rings that sweeps along the axis like scrolling lines of latitude.
float ring_band(vec3 dir, vec3 axis, float freq, float speed_scale, float width) {
	float coord = dot(dir, axis) * freq - TIME * pulse_speed * speed_scale;
	float dist_to_ring = abs(fract(coord) - 0.5) * 2.0;
	return 1.0 - smoothstep(0.0, width, dist_to_ring);
}

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.35;
	METALLIC = 0.1;

	float rim = rim_fresnel(NORMAL, VIEW);

	float rings = 0.0;
	rings += ring_band(local_dir, vec3(0.0, 1.0, 0.0), 3.0, 0.15, 0.08);
	rings += ring_band(local_dir, vec3(1.0, 0.0, 0.0), 2.0, -0.1, 0.08);
	rings += ring_band(local_dir, normalize(vec3(1.0, 1.0, 0.0)), 2.5, 0.08, 0.06);
	rings = clamp(rings, 0.0, 1.0);

	EMISSION = (rim_color.rgb * rim + ring_color.rgb * rings) * emission_strength;
}
