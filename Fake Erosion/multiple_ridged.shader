shader_type spatial;
//render_mode unshaded;

uniform float height_scale = 0.5;
uniform float ridge_persistency = 0.5;
uniform float ridge_lacunarity = 2.0;
uniform float mountain_strength = 1.0;
uniform float mountain_pow = 2.0;
uniform float seed = 1.0;
uniform vec4 mountain_color : hint_color;
uniform vec4 grass_color : hint_color;
uniform vec4 ridge_color : hint_color;

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
	float max_possible = 0.0;
	
	for (int i = 0; i < layers; i++){
		height += noise(x * frequency + seed) * amplitude;
		max_possible += amplitude;
		amplitude *= persistence;
		frequency *= lacunarity;
	}
	return height / (max_possible * 0.93);
}

float get_height(vec2 x) {
	float ridge = 0.0;
	float amplitude = 2.0;
	float frequency = 0.5;
	float weight = 1.0;
	float max_possible = 0.0;
	
	for (int i = 0; i < 3; i++){
		float v = pow((1.0 - abs(fbm(x, 2, frequency, 0.5, 2.0) - 0.5)), 2.0) * amplitude;
		v *= weight;
		weight = v;
		ridge += v;
		
		max_possible += amplitude;
		
		amplitude *= ridge_persistency;
		frequency *= ridge_lacunarity;
	}
	ridge /= max_possible;
	
	float hills = fbm(x, 5, 0.7, 0.5, 1.5);
	
	float mountain_height = pow(fbm(x, 2, 0.3, 0.5, 2.0), mountain_pow) * 1.0;
	

	return (ridge * mountain_height * 1.0 + hills * 0.5 * max(1.0 - mountain_height * 1.0, 0.0)) * height_scale;
}

void vertex() {
	vec2 sample_pos = VERTEX.xz;
	float height = get_height(sample_pos);
	VERTEX.y += height;
	COLOR = mix(grass_color, mountain_color, min(1.0, mountain_strength * height));
	COLOR.xyz = vec3(clamp(height, 1.0, 0.0));
	vec2 e = vec2(0.01, 0.0);
	vec3 normal = normalize(vec3(get_height(sample_pos - e) - get_height(sample_pos + e), 2.0 * e.x, get_height(sample_pos - e.yx) - get_height(sample_pos + e.yx)));
	NORMAL = normal;
}

void fragment() {
	ALBEDO = COLOR.xyz;
}