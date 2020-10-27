shader_type spatial;
//render_mode unshaded;

uniform float height_scale = 0.5;
uniform float scale = 1.0;
uniform float d_persistance = 0.5;
uniform float d_lacunarity = 2.0;
uniform float detail_scale = 1.0;
uniform float ridge_scale = 1.0;
uniform float r_persistance = 0.5;
uniform float r_lacunarity = 2.0;
uniform float ridge_pow = 1.0;
uniform float scale_ff = 1.1;


float hash(vec2 p) {
	return fract(sin(dot(p * 17.17, vec2(14.91, 67.31))) * 4791.9511);
}

float noise(vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	vec2 a = vec2(1.0, 0.0);
	return mix(mix(hash(p + a.yy), hash(p + a.xy), f.x),
		mix(hash(p + a.yx), hash(p + a.xx), f.x), f.y);
}

float fbm(vec2 x, int layers, float frequency, float persistence, float lacunarity) {
	float height = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < layers; i++){
		height += noise(x * frequency) * amplitude;
		amplitude *= persistence;
		frequency *= lacunarity;
	}
	return height;
}

float ridge_detail(float height) {
	return 1.0 - pow(1.0 - height, ridge_pow);
}

float ridges (vec2 x, int layers) {
	float height = 100.0;
	vec2 offset = vec2(0, 0);
	float s = 1.0;
	for (int i = 0; i < layers; i++){
		height = min(fbm((x + offset) * s, 6, ridge_scale, r_persistance, r_lacunarity) / s, height);
		offset += vec2(454, 486);
		s *= scale_ff;
	}
	return height;
}

float get_height(vec2 x) {
	float mountain = max(fbm(x, 2, detail_scale, d_persistance, d_lacunarity) - 0.2, 0.0);
	float ridge = ridges(x, 4);
	float height = ridge * mountain + ridges(x / 4.0, 3);
	//height = mountain;
	//height = ridge;
	return height;
}

void vertex() {
	vec2 sample_pos = VERTEX.xz * scale;
	float height = get_height(sample_pos);
	VERTEX.y += height * height_scale / scale;
	COLOR.xyz = vec3((height + 1.0) * 0.5);
	vec2 e = vec2(0.01, 0.0);
	vec3 normal = normalize(vec3(get_height(sample_pos - e) - get_height(sample_pos + e), 2.0 * e.x, get_height(sample_pos - e.yx) - get_height(sample_pos + e.yx)));
	NORMAL = normal;
}

void fragment() {
	ALBEDO = COLOR.xyz;
}