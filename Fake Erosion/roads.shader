// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: 

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


shader_type spatial;

uniform float seed;
uniform float scale = 1.0;
uniform float small_scale = 2.0;
uniform float road_treshold = 0.1;
uniform float small_road_treshold = 0.1;
uniform float small_end = 0.5;
uniform float pointiness = 0.5;

uniform float noise_strength = 1.0;
uniform float n_scale = 1.0;
uniform int n_num_layers = 3;
uniform float n_persistence = 0.5;
uniform float n_lacunarity = 2.0;

uniform vec4 grass_color : hint_color;
uniform vec4 road_color : hint_color;


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
	return height / (max_possible * 0.9);
}

vec2 hash2( vec2 p )
{
	// texture based white noise
	//return textureLod( iChannel0, (p+0.5)/256.0, 0.0 ).xy;
	
    // procedural white noise	
	return fract(sin(vec2(dot(p + seed,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

vec3 voronoi( in vec2 x )
{
    vec2 n = floor(x);
    vec2 f = fract(x);

    //----------------------------------
    // first pass: regular voronoi
    //----------------------------------
	vec2 mg, mr;

    float md = 8.0;
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        vec2 g = vec2(float(i),float(j));
		vec2 o = hash2( n + g );
        vec2 r = g + o - f;
        float d = dot(r,r);

        if( d<md )
        {
            md = d;
            mr = r;
            mg = g;
        }
    }

    //----------------------------------
    // second pass: distance to borders
    //----------------------------------
    md = 8.0;
    for( int j=-2; j<=2; j++ )
    for( int i=-2; i<=2; i++ )
    {
        vec2 g = mg + vec2(float(i),float(j));
		vec2 o = hash2( n + g );
        vec2 r = g + o - f;

        if( dot(mr-r,mr-r)>0.00001 ) {
        	md = min( md, dot( 0.5*(mr+r), normalize(r-mr) ) );
		}
    }

    return vec3( md, mr );
}

void fragment() {
	vec2 pos = UV * scale;
	pos += (vec2(fbm(pos + 100.0, n_num_layers, n_scale, n_persistence, n_lacunarity), fbm(pos - 54.8, n_num_layers, n_scale, n_persistence, n_lacunarity)) - 0.5) * noise_strength;
	
	vec3 big_roads = voronoi(pos);
	
	pos = UV * small_scale;
	pos += (vec2(fbm(pos + 100.0, n_num_layers, n_scale, n_persistence, n_lacunarity), fbm(pos - 54.8, n_num_layers, n_scale, n_persistence, n_lacunarity)) - 0.5) * noise_strength;
	
	vec3 small_roads = voronoi(pos);
	
	float value = float((big_roads.x > road_treshold) && (small_roads.x > small_road_treshold * ((1.0 * (1.0 - pointiness) + pointiness * (1.0 - big_roads.x / small_end))) || big_roads.x > small_end));
	vec3 color = mix(road_color, grass_color, value).xyz;
	ALBEDO = color;
}