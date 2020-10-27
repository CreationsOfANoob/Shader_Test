shader_type spatial;
//render_mode unshaded;

uniform float height_scale = 0.5;
uniform float snake_strength = 1.0;
uniform float snake_scale = 1.0;
uniform float ridge_scale = 1.0;
uniform float mountain_strength = 1.0;
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
	return height / (max_possible * 1.0);
}

float snakenoise(vec2 x, float amount) {
	vec2 offset = vec2(fbm((x + vec2(64.895, 85.654)) * snake_scale, 4, 1.0, 0.7, 2.0), fbm((x + vec2(-12.684, -45.86)) * snake_scale, 4, 1.0, 0.5, 2.0));
	float value = fbm(x + offset * amount, 3, 1.0, 0.5, 2.0);
	return value;
}

vec2 ridges (vec2 x, int layers) {
	float height = 1000.0;
	float new_height;
	vec2 offset = vec2(0, 0);
	float ridge = 0.0;
	
	for (int i = 0; i < layers; i++){
		new_height = snakenoise((x + offset) * ridge_scale, snake_strength);
		if (i > 0) {
			ridge += pow(1.0 - abs(new_height - height), 20.0) / float(layers);
		}
		height = min(new_height, height);
		offset += vec2(454, 486);
	}
	return vec2(height, ridge);
}

vec2 get_height(vec2 x) {
	vec2 ridge = ridges(x, 3);
	float height = ridge.x + (fbm(x, 3, 3.5, 0.5, 2.0) - 0.5) * (1.0 - ridge.y) * 0.1;
	float mountain = pow(fbm(x, 3, 0.5, 0.5, 2.0), 4.0) * 4.0;
	height *= mountain;
	float base = fbm(x + vec2(67, 28), 3, 0.3, 0.5, 2.0);
	
	return vec2((height + base * 0.7) * height_scale, ridge.y);
}

void vertex() {
	vec2 sample_pos = VERTEX.xz;
	vec2 ridge = get_height(sample_pos);
	float height = ridge.x;
	VERTEX.y += height;
	COLOR = mix(mix(grass_color, mountain_color, min(1.0, mountain_strength * height)), ridge_color, ridge.y * height);
	vec2 e = vec2(0.01, 0.0);
	vec3 normal = normalize(vec3(get_height(sample_pos - e).x - get_height(sample_pos + e).x, 2.0 * e.x, get_height(sample_pos - e.yx).x - get_height(sample_pos + e.yx).x));
	NORMAL = normal;
}

void fragment() {
	ALBEDO = COLOR.xyz;
}