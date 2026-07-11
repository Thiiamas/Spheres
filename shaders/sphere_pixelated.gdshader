shader_type spatial;

// screen_px_size snaps directly off FRAGCOORD, so the apparent pixel size is
// resolution-dependent: at 1920x1080 a value of 3 already reads as chunky,
// large blocks. Re-tune this uniform per target resolution/viewport rather
// than assuming the default travels well.

uniform vec4 base_color : source_color = vec4(0.72, 0.65, 0.58, 1.0);
uniform float px_resolution : hint_range(1.0, 64.0) = 10.0;
uniform float color_steps : hint_range(2.0, 16.0) = 4.0;
uniform float screen_px_size : hint_range(1.0, 32.0) = 3.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Buckets a normal into a coarse grid of directions so shading facets into
// flat chunks instead of smoothly curving across the sphere.
vec3 blocky_normal(vec3 n, float steps) {
	vec3 stepped = floor(n * steps) / steps + 0.5 / steps;
	return normalize(stepped);
}

// Cheap per-block noise so screen_px_size visibly grids the surface even
// where the (already blocky) normal shading would otherwise look flat.
float pixel_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 quantized_normal = blocky_normal(NORMAL, px_resolution);
	NORMAL = quantized_normal;

	vec2 snapped_frag = floor(FRAGCOORD.xy / screen_px_size) * screen_px_size;
	float block_noise = pixel_hash(snapped_frag) * 0.15 - 0.075;

	// Fixed key-light direction independent of scene lights, so the banding
	// stays visible even under flat/ambient-only lighting in the shader lab.
	float fake_light = clamp(dot(quantized_normal, normalize(vec3(0.4, 0.6, 0.8))), 0.0, 1.0);

	vec3 shaded = base_color.rgb * mix(0.55, 1.0, fake_light) + block_noise;
	vec3 posterized = floor(shaded * color_steps) / color_steps;

	ALBEDO = clamp(posterized, 0.0, 1.0);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
