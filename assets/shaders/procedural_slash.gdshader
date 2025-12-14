shader_type canvas_item;
render_mode unshaded, blend_mix;

// Procedural Idyllic Slash
// Designed to produce slashes and sweeps with dynamic animation

uniform vec2 texture_size = vec2(300.0, 300.0);

group_uniforms ANIMATION;
uniform float progress : hint_range(0.0, 1.0, 0.001);
uniform float time_scale : hint_range(0.0, 8.0, 0.01) = 1.0;

group_uniforms SHAPE;
uniform float final_base_pow : hint_range(0.0, 8.0, 0.01) = 1.0;

group_uniforms SHAPE.ADJUSTMENTS;
uniform int polarize_uv : hint_enum("No", "Yes") = 1;
uniform vec4 polarize_settings = vec4(0.5,0.5,0.6,1.0);
uniform float polar_rot_deg = 0.0;

group_uniforms SHAPE.DISTORTION;
uniform int apply_distortion : hint_enum("No", "Yes");
uniform sampler2D distort_texture : source_color,hint_default_black,filter_linear,repeat_enable;
uniform float distort_str : hint_range(-3.0, 3.0, 0.1) = 0.3;
uniform vec4 scroll_distortion = vec4(0.0);

group_uniforms SHAPE.BASE;
uniform int base_preset : hint_enum(
	"Custom","bsc Triangle","plr Wedge",
	"crt Trinity","plr Rhombus","bsc Square",
	"plr Taper","bsc Diamond") = 2; // Default to Wedge
uniform float base_shape_size = 1.0;
uniform float base_rot_deg = 0.0;
uniform vec4 base_position_if = vec4(0.0);
uniform vec4 base_scale_if = vec4(vec2(1.0),vec2(1.0));

group_uniforms SHAPE.BASE_APPEARANCE;
uniform float base_feather = 0.05;

group_uniforms SHAPE.FOLLOWTHROUGH;
// 0:None, 1:Xio, 2:Xi, 3:Xo, 4:Yio, 5:Yi, 6:Yo
uniform int base_scale_anim : hint_enum("None","Xio","Xi","Xo","Yio","Yi","Yo") = 1; 

group_uniforms COLORIZE;
uniform sampler2D color_gradient : source_color, hint_default_white, repeat_disable;
uniform float emission_intensity : hint_range(0.1, 16.0, 0.1) = 2.0;

group_uniforms vertex;
uniform vec2 rescale_vertex = vec2(1.0);
uniform vec2 mesh_offset = vec2(0.0);
uniform float mesh_rotation = 0.0; // Acts as Z rotation
uniform float animate_mesh_rotation = 0.0;

varying float LIFETIME;
varying float INDEX;
varying flat int PARTICLE;

const int pN = 10;
const vec2 cleanArr[pN] = {
	vec2(0.0),vec2(0.0),vec2(0.0),vec2(0.0),vec2(0.0),
	vec2(0.0),vec2(0.0),vec2(0.0),vec2(0.0),vec2(0.0)
};

struct shapedat {
	vec2 points[pN];
	int maxi;
};

// --- Math ---

float cos_wve(float x) {
	return -cos(x*2.0*3.14159)*0.5+0.5;
}

vec2 scale(vec2 uv, float x, float y, vec2 from) {
	uv -= from;
	uv = uv * mat2(vec2(x, 0.0), vec2(0.0, y));
	uv += from;
	return uv;
}

vec2 rotate(vec2 uv, vec2 pivot, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	mat2 rotation = mat2(vec2(c, -s), vec2(s, c)); // Adjusted direction
	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}

vec2 polar_coordinates(vec2 uv, vec2 center, float zoom, float repeat) {
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x) * 1.0/(3.1416 * 2.0);
	return mod(vec2(radius * zoom, angle * repeat), 1.0);
}

// --- Logic ---

vec2 scale_anim(vec2 uv, int preset, float prg) {
	vec2 nuv = uv;
	vec2 from = vec2(0.0);
	if (prg >= 0.5) {from = vec2(1.0);}
	
	switch (preset) {
		case 0: return nuv;
		case 1: // Xio (X In Out)
			float s = max(cos_wve(prg), 1.0/4096.0);
			nuv = scale(nuv, 1.0/s, 1.0, from); break;
		case 2: // Xi
			float s_i = max(cos_wve(min(prg, 0.5)), 1.0/4096.0);
			nuv = scale(nuv, 1.0/s_i, 1.0, from); break;
		case 3: // Xo
			float s_o = max(cos_wve(max(prg, 0.5)), 1.0/4096.0);
			nuv = scale(nuv, 1.0/s_o, 1.0, from); break;
		// Y variants omitted for brevity unless needed, usually slashes are longitudinal
	}
	return nuv;
}

float polygon(vec2 uv, vec2 v[pN], int maxi, float feather) {
	uv -= 0.5;
	float d = dot(uv-v[0],uv-v[0]);
	float s = 1.0;
	for( int i=0, j=maxi-1; i<maxi; j=i, i++ ) {
		vec2 e = v[j] - v[i];
		vec2 w = uv - v[i];
		vec2 b = w - e*clamp( dot(w,e)/dot(e,e), 0.0, 1.0 );
		d = min( d, dot(b,b) );
		bvec3 c = bvec3(uv.y>=v[i].y,uv.y<v[j].y,e.x*w.y>e.y*w.x);
		if( all(c) || all(not(c)) ) s*=-1.0;
	}
	// Smoothstep falloff
	return smoothstep(0.0, feather, s*sqrt(d));
}

shapedat get_shape_preset(int preset) {
	shapedat sd;
	sd.points = cleanArr;
	if (preset == 2) { // Wedge
		sd.points[0] = vec2(-0.05,-0.5);
		sd.points[1] = vec2(-0.05,0.4);
		sd.points[2] = vec2(0.0,0.3);
		sd.maxi = 3;
	} else if (preset == 4) { // Rhombus
		sd.points[0] = vec2(-0.025,-0.5);
		sd.points[1] = vec2(0.0,0.3);
		sd.points[2] = vec2(-0.025,0.35);
		sd.points[3] = vec2(-0.05,0.3);
		sd.maxi = 4;
	} else if (preset == 5) { // Arc / Swipe
		// In Polar Mode: X is Radius, Y is Angle
		// We want a ring segment at some radius
		sd.points[0] = vec2(0.15, -0.25);
		sd.points[1] = vec2(0.15, 0.25);
		sd.points[2] = vec2(0.25, 0.25);
		sd.points[3] = vec2(0.25, -0.25);
		sd.maxi = 4;
	} else { // Triangle / Arrow
		sd.points[0] = vec2(0.5, 0.0); // Tip
		sd.points[1] = vec2(-0.5, 0.4); // Back Top
		sd.points[2] = vec2(-0.5, -0.4); // Back Bottom
		sd.maxi = 3;
	}
	return sd;
}

float create_base_image(vec2 uv, float prg) {
	vec2 baseUV = uv;
	
	// Apply scale animation (the swish!)
	vec2 animated_scale_uv = scale_anim(baseUV, base_scale_anim, prg);
	
	// Apply preset shape
	shapedat bsd = get_shape_preset(base_preset);
	
	// Rotation 
	float rot = radians(base_rot_deg) + radians(90.0);
	
	float poly = 1.0 - polygon(
		rotate(animated_scale_uv, vec2(0.5), rot), 
		bsd.points, bsd.maxi, base_feather
	);
	
	return poly;
}

void vertex() {
	LIFETIME = INSTANCE_CUSTOM.y;
	
	float p = progress;
	
	// Basic transform
	vec2 tv = VERTEX - vec2(0.5) * texture_size;
	tv *= rescale_vertex;
	VERTEX = tv + vec2(0.5) * texture_size;
	
	// Mesh Rotation
	float rot_rad = radians(mesh_rotation) + (animate_mesh_rotation * p);
	float c = cos(rot_rad);
	float s = sin(rot_rad);
	mat2 rot_mat = mat2(vec2(c, -s), vec2(s, c));
	
	vec2 pos = VERTEX - vec2(0.5) * texture_size;
	pos = rot_mat * pos;
	VERTEX = pos + vec2(0.5) * texture_size;
}

void fragment() {
	vec2 uv = UV;
	float prg = progress;
	
	vec2 aUV = uv;
	
	if (polarize_uv == 1) {
		aUV = polar_coordinates(
			rotate(uv, vec2(0.5), radians(polar_rot_deg)),
			polarize_settings.xy, polarize_settings.z, polarize_settings.w
		);
	}
	
	// Distortion
	if (apply_distortion == 1) {
		float d = texture(distort_texture, uv + scroll_distortion.xy * TIME).r;
		aUV += (d - 0.5) * distort_str * 0.1;
	}

	float shape = create_base_image(aUV, prg);
	shape = pow(shape, final_base_pow);
	
	vec4 col = texture(color_gradient, vec2(shape, 0.0));
	
	vec3 final_rgb = col.rgb * emission_intensity;
	float final_a = shape * col.a;
	
	COLOR = vec4(final_rgb, final_a);
}
