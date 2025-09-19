shader_type spatial;
render_mode unshaded, shadow_to_opacity, cull_disabled;

// Note, unshaded + shadow_to_opacity means we're writing
// full transparency during the opaque pass.
// This will erase whatever is drawn and populate the depth buffer.
// This will occlude any object behind this surface.

void fragment() {
	ALBEDO = vec3(0.0, 0.0, 0.0);
}
