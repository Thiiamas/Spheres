// Requires the ShaderMaterial using this shader to have transparency = ALPHA
// set in the scene — Godot doesn't infer alpha blending from ALPHA alone.
shader_type spatial;

uniform float damage_level : hint_range(0.0, 1.0) = 0.55;
uniform float jitter_strength : hint_range(0.0, 0.2) = 0.04;
uniform float emission_strength : hint_range(0.0, 8.0) = 3.0;

uniform float cell_density : hint_range(1.0, 20.0) = 8.0;
uniform float crack_width : hint_range(0.0, 0.3) = 0.06;
// Width of the soft threshold band each cell's random dissolve point sits in —
// wider = cells fade in/out gradually as damage_level sweeps past their
// threshold, narrower = cells pop off almost instantly.
uniform float dissolve_edge : hint_range(0.01, 0.5) = 0.15;

uniform vec4 base_color : source_color = vec4(0.9, 0.32, 0.08, 1.0);
uniform vec4 critical_color : source_color = vec4(0.32, 0.02, 0.02, 1.0);
uniform vec4 crack_color : source_color = vec4(1.0, 0.75, 0.25, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Returns (F1, F2, crack_rand, dissolve_rand). The two rand channels reuse
// components of the winning cell's own placement hash rather than a fresh
// hash call — cheap and independent-looking enough for VFX purposes.
vec4 voronoi(vec3 p) {
	vec3 base_cell = floor(p);
	vec3 local_pos = fract(p);

	float f1 = 8.0;
	float f2 = 8.0;
	vec2 winner_rand = vec2(0.0);

	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point_offset = hash33(base_cell + neighbor);
				float dist = length(neighbor + point_offset - local_pos);
				if (dist < f1) {
					f2 = f1;
					f1 = dist;
					winner_rand = point_offset.yz;
				} else if (dist < f2) {
					f2 = dist;
				}
			}
		}
	}
	return vec4(f1, f2, winner_rand);
}

// Nearby vertices are grouped into the same jitter cell (rather than each
// vertex getting its own random phase) so triangles tremble as small rigid
// clusters instead of tearing apart at every edge.
vec3 jitter_effect(vec3 vertex) {
	vec3 jitter_cell = floor(vertex * 12.0);
	vec3 phase = hash33(jitter_cell) * 6.2831853;
	vec3 freq = hash33(jitter_cell + 91.7) * 8.0 + 12.0;
	vec3 tremble = vec3(
		sin(TIME * freq.x + phase.x),
		sin(TIME * freq.y + phase.y),
		sin(TIME * freq.z + phase.z)
	);
	return vertex + tremble * jitter_strength * damage_level;
}

void vertex() {
	VERTEX = jitter_effect(VERTEX);
}

void fragment() {
	vec4 v = voronoi(VERTEX * cell_density);
	float edge_dist = v.y - v.x;
	float crack_rand = v.z;
	float dissolve_rand = v.w;

	float crack = 1.0 - smoothstep(0.0, crack_width, edge_dist);
	// Cracks light up progressively: at low damage only cells whose random
	// threshold is low have visible cracks, at damage_level = 1 all of them do.
	crack *= smoothstep(crack_rand - 0.3, crack_rand + 0.3, damage_level);

	float dissolve_alpha = 1.0 - smoothstep(dissolve_rand - dissolve_edge, dissolve_rand + dissolve_edge, damage_level);
	// Keep a glowing rim visible slightly past the point a cell's body has
	// dissolved, so holes read as freshly torn/molten rather than just gone.
	float alpha = clamp(dissolve_alpha + crack * (1.0 - dissolve_alpha) * 0.5, 0.0, 1.0);
	if (alpha < 0.02) {
		discard;
	}

	ALBEDO = mix(base_color.rgb, critical_color.rgb, damage_level);
	EMISSION = crack_color.rgb * crack * emission_strength * mix(0.3, 1.0, damage_level);
	ALPHA = alpha;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
