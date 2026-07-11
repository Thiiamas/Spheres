shader_type spatial;
render_mode unshaded;

// GOTCHA: light_dir is NOT read from Godot's actual DirectionalLight3D — this
// shader is unshaded and does its own lighting entirely by hand. Whoever wires
// up shader_lab.tscn (or any scene using this material) MUST set light_dir to
// match that scene's DirectionalLight3D direction (as the direction TO the
// light, i.e. the negation of the light node's forward/-Z), or the facets will
// shade against a light that doesn't match what's actually lighting the room.
uniform vec3 light_dir = vec3(0.577, 0.577, 0.577);

uniform vec4 crystal_color : source_color = vec4(0.05, 0.40, 0.12, 1.0);
uniform vec4 edge_color : source_color = vec4(0.20, 1.00, 0.35, 1.0);
uniform float edge_emission : hint_range(0.0, 8.0) = 2.5;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.5;
// Kept separate from specular_strength so a "duller" crystal can stay bright
// on the highlight itself while narrowing/widening how tight the hotspot is.
uniform float specular_shininess : hint_range(1.0, 128.0) = 32.0;
// Higher = glow confined to sharper glancing angles, which on this coarse
// mesh reads as each facet's silhouette edge lighting up rather than a soft
// all-over rim.
uniform float edge_power : hint_range(0.5, 8.0) = 3.0;
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.35;

vec3 facet_normal(vec3 view_vertex, vec3 fallback_normal) {
	// dFdx/dFdy of the (screen-space-interpolated) view-space VERTEX is constant
	// across a single triangle, so its cross product gives one flat normal per
	// facet instead of the mesh's smooth per-vertex NORMAL — this is what makes
	// the coarse SphereMesh read as faceted rather than round.
	vec3 flat_normal = normalize(cross(dFdx(view_vertex), dFdy(view_vertex)));
	// Winding direction of dFdx/dFdy isn't guaranteed consistent between
	// triangles, so flip against the interpolated normal to avoid random
	// facets shading as if lit from behind.
	if (dot(flat_normal, fallback_normal) < 0.0) {
		flat_normal = -flat_normal;
	}
	return flat_normal;
}

void fragment() {
	vec3 flat_normal = facet_normal(VERTEX, NORMAL);
	vec3 view_dir = normalize(VIEW);
	// NORMAL/VIEW are view-space in fragment(), but light_dir is authored in
	// world space to match the scene's DirectionalLight3D — bring it into the
	// same space before comparing.
	vec3 light_dir_view = normalize((VIEW_MATRIX * vec4(normalize(light_dir), 0.0)).xyz);

	float diffuse = max(dot(flat_normal, light_dir_view), 0.0);
	// Small ambient floor so the unlit side of each facet still reads as dark
	// crystal instead of crushing to flat black.
	vec3 lit_color = crystal_color.rgb * (0.2 + 0.8 * diffuse);

	vec3 half_dir = normalize(light_dir_view + view_dir);
	float specular = pow(max(dot(flat_normal, half_dir), 0.0), specular_shininess) * specular_strength;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), view_dir), 0.0, 1.0), edge_power);
	float edge_mask = smoothstep(edge_threshold, 1.0, fresnel);

	ALBEDO = lit_color + vec3(specular);
	EMISSION = edge_color.rgb * edge_emission * edge_mask;
}
