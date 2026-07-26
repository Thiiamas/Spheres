shader_type spatial;

// Front-line combat feedback (Docs/front_unit_ai.md): calm dim rim-glow at
// idle, snaps to a hot pulsing color while attack_amount rises. Driven by
// FrontUnit.is_attacking from script — fragment-only, so it reads the same
// on the ally sphere and the enemy cube.

uniform vec4 base_color : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform vec4 attack_color : source_color = vec4(1.0, 0.25, 0.1, 1.0);
uniform float attack_amount : hint_range(0.0, 1.0) = 0.0;
uniform float idle_emission : hint_range(0.0, 4.0) = 0.3;
uniform float attack_emission : hint_range(0.0, 8.0) = 5.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 10.0;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.4;

float fresnel(vec3 normal, vec3 view) {
	return pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 2.5);
}

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = surface_roughness;

	float rim = fresnel(NORMAL, VIEW);
	// Fast flicker only kicks in while attacking, so idle units read as calm.
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);
	float glow = mix(idle_emission, attack_emission * pulse, attack_amount);

	EMISSION = mix(base_color.rgb, attack_color.rgb, attack_amount) * rim * glow;
}
