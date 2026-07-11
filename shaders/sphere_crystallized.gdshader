shader_type spatial;

// Needs a SphereMesh with high subdivision (128 radial segments / 64 rings) —
// the facet look comes entirely from per-vertex displacement + finite-diff
// normals, so sparse geometry reads as jagged lumps instead of pointed spikes.

uniform vec4 base_color : source_color = vec4(0.55, 0.04, 0.08, 1.0);
uniform float spike_height : hint_range(0.0, 1.0) = 0.28;
uniform float spike_freq : hint_range(1.0, 20.0) = 5.5;
uniform float spike_sharpness : hint_range(0.0, 1.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform float metallic : hint_range(0.0, 1.0) = 0.15;

varying float spike_amount;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			dot(p, vec3(269.5, 183.3, 246.1)),
			dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

// Worley/cell noise on the direction sphere: each cell gets a random feature
// point, and distance-to-nearest-point naturally produces a cone per cell
// with hard boundaries between them — that's what gives the facets rather
// than smooth bumps. Sharpness narrows each cone into a point via pow().
float spike_pattern(vec3 dir) {
	vec3 p = dir * spike_freq;
	vec3 cell = floor(p);
	vec3 local = fract(p);

	float best_dist = 10.0;
	float peak_height = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 offset = vec3(float(x), float(y), float(z));
				vec3 rand = hash3(cell + offset);
				float dist = length(offset + rand - local);
				if (dist < best_dist) {
					best_dist = dist;
					peak_height = rand.x;
				}
			}
		}
	}

	float cone = 1.0 - clamp(best_dist, 0.0, 1.0);
	float sharpness_pow = mix(1.0, 8.0, spike_sharpness);
	return pow(cone, sharpness_pow) * peak_height;
}

vec3 displaced_position(vec3 dir, float radius) {
	float h = spike_pattern(dir);
	return dir * (radius + h * spike_height * radius);
}

void vertex() {
	vec3 dir = normalize(VERTEX);
	float radius = length(VERTEX);
	vec3 new_pos = displaced_position(dir, radius);

	// Sample two nearby directions and rebuild the normal from the resulting
	// triangle instead of smoothing NORMAL — that's what keeps the spike
	// tips and facet edges looking crisp rather than rounded off.
	vec3 tangent = normalize(cross(dir, abs(dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 bitangent = normalize(cross(dir, tangent));
	float eps = 0.01;

	vec3 dir_a = normalize(dir + tangent * eps);
	vec3 dir_b = normalize(dir + bitangent * eps);
	vec3 pos_a = displaced_position(dir_a, radius);
	vec3 pos_b = displaced_position(dir_b, radius);

	vec3 facet_normal = normalize(cross(pos_a - new_pos, pos_b - new_pos));
	if (dot(facet_normal, NORMAL) < 0.0) {
		facet_normal = -facet_normal;
	}

	VERTEX = new_pos;
	NORMAL = facet_normal;
	spike_amount = spike_pattern(dir);
}

void fragment() {
	// Crevices (low spike_amount) read darker, tips catch more light —
	// mimics how light rakes across a geode's inner points vs. its base.
	float tone = mix(0.55, 1.2, spike_amount);
	ALBEDO = base_color.rgb * tone;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
