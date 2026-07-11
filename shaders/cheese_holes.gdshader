shader_type spatial;

const int HOLE_COUNT = 4;

// Godot's shader language doesn't allow default values on uniform arrays —
// defaults for these three live on the ShaderMaterial in shader_lab.tscn instead.
uniform vec3 hole_centers[4];
uniform float hole_radius[4];
uniform float hole_depth[4];

uniform vec4 base_color : source_color = vec4(0.7, 0.75, 0.85, 1.0);
uniform vec4 hole_color : source_color = vec4(0.85, 0.3, 0.15, 1.0);
// Lower = hole_color reaches full strength closer to the rim, leaving only a
// thin transition band — kept separate from the geometric falloff so the
// crater shape can stay smooth while the color itself reads as a bold, solid
// fill rather than a wide fade.
uniform float hole_color_sharpness : hint_range(0.01, 1.0) = 0.25;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
// 0 = no glow (lab default). An identity that wants the holes to read as
// "light shining through a hollow shell" can raise this instead of touching
// hole_color itself.
uniform float hole_glow_energy : hint_range(0.0, 4.0) = 0.0;

varying float hole_mix;

void vertex() {
	vec3 vertex_dir = normalize(VERTEX);

	float best_falloff = 0.0;
	int best_index = 0;
	for (int i = 0; i < HOLE_COUNT; i++) {
		vec3 center_dir = normalize(hole_centers[i]);
		float closeness = dot(vertex_dir, center_dir);
		float falloff = smoothstep(1.0 - hole_radius[i], 1.0, closeness);
		// Strongest hole wins per vertex; summing overlapping holes would dig
		// twice as deep wherever two of them meet.
		if (falloff > best_falloff) {
			best_falloff = falloff;
			best_index = i;
		}
	}

	float depth = max(hole_depth[best_index], 0.0001);
	vec3 center_dir = normalize(hole_centers[best_index]);
	vec3 displaced = VERTEX - NORMAL * best_falloff * depth;

	// Treat the winning hole as if a smaller sphere had been sunk into the
	// surface along its axis; any point on that inner sphere faces away from
	// its own center, so this normal actually curves through the cavity
	// instead of staying identical to the flat outward sphere normal. The
	// inner sphere is offset by 2x depth (not depth) so it doesn't coincide
	// with the crater's own deepest point — at falloff=1 that would make
	// `displaced - inner_sphere_center` a zero vector and normalize() a NaN
	// right at the center of every hole. Offsetting further gives the inner
	// sphere a nonzero curvature radius (equal to depth) at that point.
	vec3 inner_sphere_center = VERTEX - center_dir * depth * 2.0;
	vec3 bowl_normal = normalize(displaced - inner_sphere_center);

	VERTEX = displaced;
	NORMAL = normalize(mix(NORMAL, bowl_normal, best_falloff));
	hole_mix = best_falloff;
}

void fragment() {
	float color_mix = smoothstep(0.0, hole_color_sharpness, hole_mix);
	ALBEDO = mix(base_color.rgb, hole_color.rgb, color_mix);
	ALPHA = mix(base_color.a,hole_color.a, color_mix);
	EMISSION = hole_color.rgb * color_mix * hole_glow_energy;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
