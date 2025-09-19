shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D roughness_texture : hint_default_white;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec2 uv_scale = vec2(1.0, 1.0);

void vertex() {
	// Called for every vertex the material is visible on.
	UV = UV * uv_scale;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 color = texture(albedo_texture, UV);
	ALBEDO = color.rgb * albedo.rgb;
	NORMAL = texture(normal_texture, UV).rgb;
	ROUGHNESS = texture(roughness_texture, UV).r;
	METALLIC = metallic;
	SPECULAR = specular;
}
