struct Scene {
    plane: Plane,
    triangle: Triangle,
    sphere: Sphere,
    light: PointLight,
};

struct Color {
    ambient: vec3f,
    diffuse: vec3f,
    specular: vec3f,
};

struct Plane {
    position: vec3f,
    normal: vec3f,
    color: Color,
};

struct Triangle {
    vertices: array<vec3f, 3>,
    color: Color,
};

struct Sphere {
    center: vec3f,
    _pad0: f32,
    radius: f32,
    refractive_index: f32,
    shininess: f32,
    color: Color,
};

struct PointLight {
    position: vec3f,
    intensity: vec3f,
}

struct Uniforms {
    aspect: f32,
    cam_const: f32,
    gamma: f32,
    _pad0: f32,
    matt_shader: f32, // uniform array is an f32 array
    glass_shader: f32, // convert these to u32 when using
    texture_lookup: f32,
    texture_filtering: f32,
    eye: vec3f,
    b1: vec3f,
    b2: vec3f,
    v: vec3f,
    scene: Scene,
};
@group(0) @binding(0) var<uniform> uniforms : Uniforms;

@group(0) @binding(1) var texture : texture_2d<f32>;

struct Ray {
    origin: vec3f,
    direction: vec3f,
    tmin: f32,
    tmax: f32
};

struct HitInfo {
    has_hit: bool,
    dist: f32,
    position: vec3f,
    normal: vec3f,
    color: Color,
    shader: u32,
    refraction_ratio: f32,
};

struct Light {
    L_i: vec3f,
    w_i: vec3f,
    dist: f32,
};

struct VSOut {
    @builtin(position) position: vec4f,
    @location(0) coords : vec2f,
};

@vertex
fn main_vs(@builtin(vertex_index) VertexIndex : u32) -> VSOut {
    const pos = array<vec2f, 4>(vec2f(-1.0, 1.0), vec2f(-1.0, -1.0), vec2f(1.0, 1.0), vec2f(1.0, -1.0));
    var vsOut: VSOut;
    vsOut.position = vec4f(pos[VertexIndex], 0.0, 1.0);
    vsOut.coords = pos[VertexIndex];
    return vsOut;
}

fn get_camera_ray(ipcoords: vec2f) -> Ray {
    // Implement ray generation (WGSL has vector operations like normalize and cross)

    // ray in camera basis
    let q = uniforms.b1 * ipcoords.x + uniforms.b2 * ipcoords.y + uniforms.v * uniforms.cam_const;
    // normalize to get direction
    let w = normalize(q);

    var ray: Ray;
    ray.origin = uniforms.eye;
    ray.direction = w;
    ray.tmin = 0.0;
    ray.tmax = 1e30;
    return ray;
}

fn intersect_plane(ray: Ray, hit: ptr<function, HitInfo>, plane: Plane) -> bool {
    let dp = dot(ray.direction, plane.normal);

    if (dp == 0) { return false; }
    
    let t = dot(plane.position - ray.origin, plane.normal) / dp;

    if (t < 0) { return false; }

    if ((ray.tmin < t) & (t < ray.tmax)) {
        hit.dist = t;
        hit.has_hit = true;
        hit.color = plane.color;
        hit.normal = plane.normal;
        hit.position = ray.origin + t * ray.direction;
        hit.shader = u32(uniforms.matt_shader);

        return true;
    }
    
    return false;
}

fn intersect_triangle(ray: Ray, hit: ptr<function, HitInfo>, triangle: Triangle) -> bool {
    
    let e0 = triangle.vertices[1] - triangle.vertices[0];
    let e1 = triangle.vertices[2] - triangle.vertices[0];
    
    let normal = cross(e0, e1);

    let dp = dot(ray.direction, normal);

    if (dp == 0) { return false; }

    let o_to_v0 = triangle.vertices[0] - ray.origin;

    let t = dot(o_to_v0, normal) / dp;

    let cp = cross(o_to_v0, ray.direction);

    let beta = dot(cp, e1) / dp;
    let gamma = -dot(cp, e0) / dp;

    if (!((beta >= 0) & (gamma >= 0) & (beta + gamma <= 1))) { return false; }
    
    if ((ray.tmin < t) & (t < ray.tmax)) {
        hit.dist = t;
        hit.has_hit = true;
        hit.color = triangle.color;
        hit.normal = normalize(normal);
        hit.position = ray.origin + t * ray.direction;
        hit.shader = u32(uniforms.matt_shader);

        return true;
    }

    return false;
}

fn intersect_sphere(ray: Ray, hit: ptr<function, HitInfo>, sphere: Sphere) -> bool {
    let origin_minus_center = ray.origin - sphere.center;
    let b_half = dot(origin_minus_center, ray.direction);
    let c = dot(origin_minus_center, origin_minus_center) - sphere.radius * sphere.radius;
    let d = b_half * b_half - c;

    if d < 0 {
        return false;
    }

    let t1 = -b_half - sqrt(d);
    var p = ray.origin + t1 * ray.direction;
    var normal = normalize(p - sphere.center);

    if t1 > ray.tmin && t1 < ray.tmax {
        hit.has_hit = true;
        hit.dist = t1;
        hit.position = p;
        hit.normal = normal;
        hit.color = sphere.color;
        hit.refraction_ratio = 1.0 / 1.5;
        hit.shader = u32(uniforms.glass_shader);
        return true;
    }

    let t2 = -b_half + sqrt(d);

    if t2 > ray.tmin && t2 < ray.tmax {
        var p = ray.origin + t2 * ray.direction;
        var normal = normalize(p - sphere.center);

        hit.has_hit = true;
        hit.dist = t2;
        hit.position = p;
        hit.normal = normal;
        hit.color = sphere.color;
        hit.refraction_ratio = 1.0 / 1.5;
        hit.shader = u32(uniforms.glass_shader);
        return true;
    }

    return false;
}

fn intersect_scene(r: ptr<function, Ray>, hit : ptr<function, HitInfo>) -> bool {
    // For each intersection found, update r.tmax and store additional info about the hit.
    let plane = uniforms.scene.plane;
    let triangle = uniforms.scene.triangle;
    let sphere = uniforms.scene.sphere;

    intersect_sphere(*r, hit, sphere);
    if (hit.has_hit) {
        r.tmax = hit.dist;
    }
    intersect_triangle(*r, hit, triangle);
    if (hit.has_hit) {
        r.tmax = hit.dist;
    }
    intersect_plane(*r, hit, plane);
    if (hit.has_hit) {
        r.tmax = hit.dist;
    }

    return hit.has_hit;
}

fn sample_point_light(position: vec3f) -> Light {
    let point_light = uniforms.scene.light;

    let diff = point_light.position - position;
    let dist = length(diff);

    return Light(
        point_light.intensity / (dist * dist),
        diff / dist,
        dist,
    );
}

fn lambertian(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
    
    let light = sample_point_light(hit.position);
    
    var color = Color(vec3f(0.0), vec3f(0.0), vec3f(0.0));
    var shadow_hit = HitInfo(
        false, 
        0.0,
        vec3f(0.0), 
        vec3f(0.0), 
        color, 
        1,
        1.0,
    );
    var shadow_ray = Ray(hit.position, light.w_i, 1e-4, light.dist);

    let shadow = intersect_scene(&shadow_ray, &shadow_hit);

    if (shadow) {
        return hit.color.ambient;
    }
    
    let angle_of_incidence = dot(hit.normal, r.direction);

    let l_o = hit.color.diffuse * light.L_i * angle_of_incidence;

    return l_o + hit.color.ambient;
}

fn phong(ray: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
    let light = sample_point_light(hit.position);

    let r = reflect(-light.w_i, hit.normal); 
    let w_o = normalize(uniforms.eye - hit.position);
    let s = 42.0;

    let c = hit.color;

    let cos_alpha = max(dot(r, w_o), 0.0);
    let cos_theta_i = max(dot(light.w_i, hit.normal), 0.0);

    let l_o = c.diffuse / 3.14 + (s + 2) / 6.28 * c.specular * pow(cos_alpha, s) * light.L_i * cos_theta_i;
    
    return l_o + hit.color.ambient;
}

fn mirror(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
    //return hit.color.ambient;
    let v = reflect(r.direction, hit.normal);

    r.origin = hit.position;
    r.direction = v;
    r.tmin = 1e-4;
    r.tmax = 1e30;

    // continue tracing
    hit.has_hit = false;
    hit.shader = 0;

    // mirror does not add any color to the ray (yet)
    return vec3f(0.0);
}

fn refraction(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
    
    let dotp = dot(r.direction, hit.normal);

    // internal collision
    // normals are defined to always point "outwards"
    if (dotp > 0) {
        hit.normal *= -1;
        hit.refraction_ratio = 1 / hit.refraction_ratio;
    }

    let w_t = refract(
        r.direction, 
        hit.normal, 
        hit.refraction_ratio
    );

    r.origin = hit.position;
    r.direction = w_t;
    r.tmin = 1e-4;
    r.tmax = 1e30;

    // continue tracing
    hit.has_hit = false;
    hit.shader = 0;

    // refraction does not add any color to the ray (yet)
    return vec3f(0.0);
}

fn glossy(ray: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
    
    let r = refraction(ray, hit);
    let p = phong(ray, hit);

    return r + p;
}

fn shade(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
    switch hit.shader {
        case 1 { return lambertian(r, hit); }
        case 2 { return phong(r, hit); }
        case 3 { return mirror(r, hit); }
        case 4 { return refraction(r, hit); }
        case 5 { return glossy(r, hit); }
        case default { return hit.color.ambient + hit.color.diffuse; }
    }
}

fn texture_nearest(texture: texture_2d<f32>, texcoords: vec2f, repeat: bool) -> vec3f {
    let res = textureDimensions(texture);
    
    let st = select(
        clamp(texcoords, vec2f(0.0), vec2f(1.0)), 
        texcoords - floor(texcoords),
        repeat,
    );
    
    let ab = st * vec2f(res);

    let uv = vec2u(ab + 0.5) % res;

    let texcolor = textureLoad(texture, uv, 0);

    return texcolor.rgb;
}

fn texture_linear(texture: texture_2d<f32>, texcoords: vec2f, repeat: bool) -> vec3f {
    let res = textureDimensions(texture);
    
    let st = select(
        clamp(texcoords, vec2f(0.0), vec2f(1.0)), 
        texcoords - floor(texcoords),
        repeat,
    );
    
    let ab = st * vec2f(res);

    let uv = vec2u(ab);

    let cxy = ab - vec2f(uv);
    let cx = cxy.x;
    let cy = cxy.y;

    let uv1 = (uv + vec2u(1, 0)) % res;
    let uv2 = (uv + vec2u(0, 1)) % res;
    let uv3 = (uv + vec2u(1)) % res;

    let texcolor = 
        (1 - cx) * (1 - cy) * textureLoad(texture, uv, 0) +
        cx * (1 - cy) * textureLoad(texture, uv1, 0) +
        (1 - cx) * cy * textureLoad(texture, uv2, 0) +
        cx * cy * textureLoad(texture, uv3, 0);
    
    return texcolor.rgb;
}

@fragment
fn main_fs(@location(0) coords: vec2f) -> @location(0) vec4f {
    
    var texcolor = vec3f(0.0);
    if uniforms.texture_filtering == 1.0 {
        texcolor = texture_linear(
            texture, 
            coords * 0.1, 
            uniforms.texture_lookup == 0.0,
        );
    } else {
        texcolor = texture_nearest(
            texture, 
            coords * 0.1, 
            uniforms.texture_lookup == 0.0,
        );
    }
    
    return vec4f(texcolor, 1.0);

    // not needed for first exercise
    //const bgcolor = vec4f(0.1, 0.3, 0.6, 1.0);
    //const max_depth = 10;
    //let uv = vec2f(coords.x*uniforms.aspect*0.5f, coords.y*0.5f);
    //var r = get_camera_ray(uv);
    //var result = vec3f(0.0);
    //var color = Color(vec3f(0.0), vec3f(0.0), vec3f(0.0));
    //var hit = HitInfo(false, 0.0, vec3f(0.0), vec3f(0.0), color, 1, 1.0);
    //for(var i = 0; i < max_depth; i++) {
    //    if(intersect_scene(&r, &hit)) { 
    //        result += shade(&r, &hit);
    //        //if ((i > 0) && (i <= 3)) {
    //        //    var c = vec3f(0.0);
    //        //    c[i - 1] = 1.0;
    //        //    result = c;
    //        //}
    //    } else { 
    //        result += bgcolor.rgb;
    //        break;
    //    }
    //    if(hit.has_hit) { break; }
    //}
    //return vec4f(pow(result, vec3f(1.0/uniforms.gamma)), bgcolor.a);
}