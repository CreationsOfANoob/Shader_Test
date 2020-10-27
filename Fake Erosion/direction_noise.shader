shader_type spatial;
//render_mode unshaded;

uniform float height_scale = 0.5;
uniform float seed = 1.0;
uniform float noise_direction = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p * 17.17, vec2(14.91, 67.31))) * 4791.9511);
}

vec2 hash_dir(vec2 x ) {
	vec2 k = vec2( 0.3183099, 0.3678794);
	x = x*k + k.yx;
	return -1.0 + 2.0*fract( 16.0 * k*fract( x.x*x.y*(x.x+x.y)) );
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

vec3 erosion(vec2 p, vec2 dir) {
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    float f = 2.0 * 3.14159265;
    vec3 va = vec3(0.0);
   	float wt = 0.0;
    for (int i=-2; i<=1; i++) {
		for (int j=-2; j<=1; j++) {		
        	vec2 o = vec2(float(i), float(j));
        	vec2 h = hash_dir(ip - o)*0.5;
            vec2 pp = fp +o - h;
            float d = dot(pp, pp);
            float w = exp(-d*2.0);
            wt +=w;
            float mag = dot(pp,dir);
            va += vec3(cos(mag*f), -sin(mag*f)*(pp+dir))*w;
        }
    }
    return va/wt;
}

vec3 noised( in vec2 p )
{
    vec2 i = floor( p );
    vec2 f = fract( p );

    vec2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
	vec2 du = 30.0*f*f*(f*(f-2.0)+1.0); 
	
	vec2 ga = hash_dir( i + vec2(0.0,0.0) );
	vec2 gb = hash_dir( i + vec2(1.0,0.0) );
	vec2 gc = hash_dir( i + vec2(0.0,1.0) );
	vec2 gd = hash_dir( i + vec2(1.0,1.0) );
	
	float va = dot( ga, f - vec2(0.0,0.0) );
	float vb = dot( gb, f - vec2(1.0,0.0) );
	float vc = dot( gc, f - vec2(0.0,1.0) );
	float vd = dot( gd, f - vec2(1.0,1.0) );
	
	return vec3( va + u.x*(vb-va) + u.y*(vc-va) + u.x*u.y*(va-vb-vc+vd),   // value
		ga + u.x*(gb-ga) + u.y*(gc-ga) + u.x*u.y*(ga-gb-gc+gd) +  // derivatives
		du * (u.yx*(va-vb-vc+vd) + vec2(vb,vc) - va));
}



//This is where the magic happens
vec3 mountain(vec2 p, float s) {
    //First generate a base heightmap
    //it can be based on any type of noise
    //so long as you also generate normals
    //Im just doing basic FBM based terrain using
    //iq's analytic derivative gradient noise
    vec3 n = vec3(0.0);
    float nf = 1.0;
    float na = 0.6;
    for (int i=0;i<4;i++) {
       n+= noised(p*s*nf)*na*vec3(1.0, nf, nf);
       na *= 0.5;
       nf *= 2.0;
    }
    
    //take the curl of the normal to get the gradient facing down the slope
    vec2 dir = n.zy*vec2(1.0, -1.0);
    
    //Now we compute another fbm type noise
    // erosion is a type of noise with a strong directionality
    //we pass in the direction based on the slope of the terrain
    //erosion also returns the slope. we add that to a running total
    //so that the direction of successive layers are based on the
    //past layers
    vec3 h = vec3(0.0);
    float a = 0.7*(smoothstep(0.3, 0.5,n.x*0.5+0.5)); //smooth the valleys
    float f = 1.0;
    for (int i=0;i<2;i++) {
        h+= erosion(p*f, dir+h.zy*vec2(1.0, -1.0))*a*vec3(1.0, f, f);
        a*=0.4;
        f*=2.0;
    }
    //remap height to [0,1] and add erosion
    //looks best when erosion amount is small
    //not sure about adding the normals together, but it looks okay
    return vec3(smoothstep(-1.0, 1.0, n.x)+h.x*0.05, (n.yz+h.yz)*0.5+0.5);
}

float get_height(vec2 x) {
	vec3 ridge = mountain(x, noise_direction);

	return ridge.x * height_scale;
}

void vertex() {
	vec2 sample_pos = VERTEX.xz;
	float height = get_height(sample_pos);
	VERTEX.y += height;
	COLOR.xyz = vec3(clamp(height, 1.0, 0.0));
	vec2 e = vec2(0.01, 0.0);
	vec3 normal = normalize(vec3(get_height(sample_pos - e) - get_height(sample_pos + e), 2.0 * e.x, get_height(sample_pos - e.yx) - get_height(sample_pos + e.yx)));
	NORMAL = normal;
}

void fragment() {
	ALBEDO = COLOR.xyz;
}