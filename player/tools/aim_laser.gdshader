shader_type spatial;
render_mode unshaded;

varying float alpha;
void vertex() {
	alpha = (VERTEX.z + 0.15) / 0.4;
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALPHA = alpha;
}

