shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform sampler2D albedo_texture : source_color, repeat_enable;
uniform vec2 uv_scale = vec2(10.0, 10.0);

uniform float circle_size = 0.05;
uniform float inner_size = 0.2;
uniform float fade_size = 0.3;

void vertex() {
	// Called for every vertex the material is visible on.
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	UV2 = world_vertex.xz * uv_scale;
}

void fragment() {
	float dist = length(UV - vec2(0.5, 0.5));
	float alpha = 1.0 - clamp((dist - inner_size) / fade_size, 0.0, 1.0);
	vec4 color = vec4(1.0, 0.0, 0.0, 1.0);

	if (dist > circle_size) {
		color = texture(albedo_texture, UV2);
	}

	ALBEDO = color.rgb;
	ALPHA = color.a * alpha;
}
