// Spectrale tribe: ghostly, barely-there core with a bright fresnel rim.
// Requires the ShaderMaterial's transparency set to ALPHA in the scene, or
// the translucency here has no effect.
shader_type spatial;

uniform vec4 core_color : source_color = vec4(0.10, 0.25, 0.70, 1.0);
uniform vec4 rim_color : source_color = vec4(0.40, 0.75, 1.00, 1.0);
uniform float center_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.80;
uniform float fresnel_power : hint_range(1.0, 8.0) = 3.0;
uniform float rim_glow_energy : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);

	ALBEDO = mix(core_color.rgb, rim_color.rgb, fresnel);
	ALPHA = mix(center_alpha, rim_alpha, fresnel);
	// Scale by fresnel again (not just rim_glow_energy) so the core stays dim
	// even if rim_glow_energy is cranked up for a punchier silhouette.
	EMISSION = rim_color.rgb * rim_glow_energy * fresnel;
}
