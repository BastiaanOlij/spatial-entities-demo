shader_type spatial;
render_mode unshaded;

uniform vec4 on_color : source_color = vec4(0.8, 0.8, 0.8, 0.5);
uniform vec4 off_color : source_color = vec4(0.2, 0.2, 0.2, 0.5);
uniform float cube_size = 0.1;

varying vec3 world_vertex;

void vertex() {
	// Called for every vertex the material is visible on.
	// world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz / cube_size;
	world_vertex = VERTEX / cube_size;
}

void fragment() {
	// Called for every pixel the material is visible on.
	float v = 0.0;
	if (mod(world_vertex.x, 1.0) > 0.51) {
		v = 1.0 - v;
	}
	if (mod(world_vertex.y, 1.0) > 0.51) {
		v = 1.0 - v;
	}
	if (mod(world_vertex.z, 1.0) > 0.51) {
		v = 1.0 - v;
	}

	vec4 color = mix(off_color, on_color, v);
	ALBEDO = color.rgb;
	ALPHA = color.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
