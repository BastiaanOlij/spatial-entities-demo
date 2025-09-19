shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color;
uniform vec2 uv_scale = vec2(1.0, 1.0);

void vertex() {
	// Called for every vertex the material is visible on.
	UV = UV * uv_scale;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 color = texture(albedo_texture, UV);
	ALBEDO = color.rgb * albedo.rgb;
}
