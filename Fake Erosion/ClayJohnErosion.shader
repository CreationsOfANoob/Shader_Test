// Originally from https://www.shadertoy.com/view/MtGcWh by user clayjohn
// With some small modifications

//Copyright 2020 Clay John

//Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
//and associated documentation files (the "Software"), to deal in the Software without restriction, 
//including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do 
//so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all copies or 
//substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
//NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
//IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
//WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
//SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



shader_type spatial;
//render_mode unshaded;

uniform float height_scale = 0.5;
uniform float seed = 1.0;
uniform float noise_direction = 0.0;
uniform vec4 mountain_color : hint_color;
uniform vec4 grass_color : hint_color;
uniform float mountain_strength = 1.0;
uniform float grass_start = 0.0;
uniform float ridge_influence = 1.0;
uniform bool experimental = false;
uniform float erosion_normal_strength = 1.0;
uniform float erosion_strength = 0.05;

uniform float scale = 1.0;

vec2 hash( in vec2 x ) 
{
	x += seed;
    vec2 k = vec2( 0.3183099, 0.3678794 );
    x = x*k + k.yx;
    return -1.0 + 2.0*fract( 16.0 * k*fract( x.x*x.y*(x.x+x.y)) );
}


// from https://www.shadertoy.com/view/XdXBRH
//name:Noise - Gradient - 2D - Deriv
//Author: iq
// return gradient noise (in x) and its derivatives (in yz)
vec3 noised( in vec2 p )
{
    vec2 i = floor( p );
    vec2 f = fract( p );

    vec2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
    vec2 du = 30.0*f*f*(f*(f-2.0)+1.0); 
    
    vec2 ga = hash( i + vec2(0.0,0.0) );
    vec2 gb = hash( i + vec2(1.0,0.0) );
    vec2 gc = hash( i + vec2(0.0,1.0) );
    vec2 gd = hash( i + vec2(1.0,1.0) );
    
    float va = dot( ga, f - vec2(0.0,0.0) );
    float vb = dot( gb, f - vec2(1.0,0.0) );
    float vc = dot( gc, f - vec2(0.0,1.0) );
    float vd = dot( gd, f - vec2(1.0,1.0) );

    return vec3( va + u.x*(vb-va) + u.y*(vc-va) + u.x*u.y*(va-vb-vc+vd),   // value
                 ga + u.x*(gb-ga) + u.y*(gc-ga) + u.x*u.y*(ga-gb-gc+gd) +  // derivatives
                 du * (u.yx*(va-vb-vc+vd) + vec2(vb,vc) - va));
}


// code adapted from https://www.shadertoy.com/view/llsGWl
// name: Gavoronoise
// author: guil
//Code has been modified to return analytic derivatives and to favour 
//direction quite a bit.
vec3 erosion(in vec2 p, vec2 dir) {    
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    float f = 2.* 3.14159;
    vec3 va = vec3(0.0);
   	float wt = 0.0;
    for (int i=-2; i<=1; i++) {
		for (int j=-2; j<=1; j++) {		
        	vec2 o = vec2(float(i), float(j));
        	vec2 h = hash(ip - o)*0.5;
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
    for (int i=0;i<2;i++) {
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
	vec2 e_n = vec2(0.0);
    float a = 0.7*(smoothstep(0.3, 0.5,n.x*0.5+0.5)); //smooth the valleys
    float f = 1.0;
    for (int i=0;i<5;i++) {
		e_n += h.yz * a;
        h+= erosion(p*f, dir+h.zy*vec2(1.0, -1.0))*a*vec3(1.0, f, f);
        a*=0.35;
        f*=2.0;
    }
    //remap height to [0,1] and add erosion
    //looks best when erosion amount is small
    //not sure about adding the normals together, but it looks okay
    return vec3(n.x + h.x * erosion_strength, (n.yz + e_n * erosion_normal_strength));
}

vec3 get_height(vec2 x) {
	vec3 ridge = mountain(x, noise_direction);

	return ridge;
}

void vertex() {
	vec2 sample_pos = VERTEX.xz * scale;
	vec3 h = get_height(sample_pos);
	
	float real_height_scale = height_scale / scale;
	float height = h.x * real_height_scale;
	VERTEX.y += height;
	COLOR.xyz = vec3(clamp(height, 0.7, 0.0));
	
	vec2 e = vec2(0.01, 0.0);
	vec3 normal;
	if (experimental) {
		normal = normalize(vec3(-h.y * e.x * height_scale, 2.0 * e.x, -h.z * e.x * height_scale));
	} else {
		normal = normalize(vec3(get_height(sample_pos - e).x * real_height_scale - get_height(sample_pos + e).x * real_height_scale, 2.0 * e.x, get_height(sample_pos - e.yx).x * real_height_scale - get_height(sample_pos + e.yx).x * real_height_scale));
	}
	COLOR = mix(grass_color, mountain_color, clamp(mountain_strength * (height / real_height_scale - grass_start) + length(normal.xz) * ridge_influence, 1.0, 0.0));
	NORMAL = normal;
}

void fragment() {
	ALBEDO = COLOR.xyz;
}