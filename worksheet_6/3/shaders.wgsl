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

struct Onb {
tangent: vec3f,
binormal: vec3f,
normal: vec3f,
};
const plane_onb = Onb(
    vec3f(-1.0, 0.0, 0.0), 
    vec3f(0.0, 0.0, 1.0), 
    vec3f(0.0, 1.0, 0.0)
);

struct Uniforms {
    aspect: f32,
    cam_const: f32,
    gamma: f32,
    texturing: f32,
    matt_shader: f32, // uniform array is an f32 array
    glass_shader: f32, // convert these to u32 when using
    texture_lookup: f32,
    texture_filtering: f32,
    subdivision_level: f32,
    texture_magnification: f32,
    lightIdx1: f32,
    lightIdx2: f32,
    eye: vec3f,
    b1: vec3f,
    b2: vec3f,
    v: vec3f,
    scene: Scene,
};
@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var<storage> jitter: array<vec2f>;
@group(0) @binding(2) var<storage> attributes: array<VertexAttributes>;
@group(0) @binding(3) var<storage> meshFaces: array<vec4u>;
@group(0) @binding(5) var<storage> materials: array<Material>;
@group(0) @binding(6) var<uniform> aabb: AABB;
@group(0) @binding(7) var<storage> bspPlanes: array<f32>;
@group(0) @binding(8) var<storage> bspTree: array<vec4u>;
@group(0) @binding(9) var<storage> treeIds: array<u32>;

const MAX_LEVEL = 20u;
const BSP_LEAF = 3u;
var<private> branch_node: array<vec2u, MAX_LEVEL>;
var<private> branch_ray: array<vec2f, MAX_LEVEL>;

struct VertexAttributes {
    vPosition: vec3f,
    normal: vec3f,
}

struct Material {
    emission: vec3f,
    diffuse: vec3f,
};

struct AABB {
    min: vec3f,
    max: vec3f,
};

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


fn intersect_trimesh(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> bool
{
    var branch_lvl = 0u;
    var near_node = 0u;
    var far_node = 0u;
    var t = 0.0f;
    var node = 0u;
    for(var i = 0u; i <= MAX_LEVEL; i++) {
        let tree_node = bspTree[node];
        let node_axis_leaf = tree_node.x&3u;
        if(node_axis_leaf == BSP_LEAF) {
            let node_count = tree_node.x>>2u;
            let node_id = tree_node.y;
            var found = false;
            for(var j = 0u; j < node_count; j++) {
                let obj_idx = treeIds[node_id + j];
                if(intersect_triangle(*r, hit, obj_idx)) {
                    r.tmax = hit.dist;
                    found = true;
                }
            }
            if(found) { return true; }
            else if(branch_lvl == 0u) { return false; }
            else {
                branch_lvl--;
                i = branch_node[branch_lvl].x;
                node = branch_node[branch_lvl].y;
                r.tmin = branch_ray[branch_lvl].x;
                r.tmax = branch_ray[branch_lvl].y;
                continue;
            }
        }

        let axis_direction = r.direction[node_axis_leaf];
        let axis_origin = r.origin[node_axis_leaf];

        if(axis_direction >= 0.0f) {
            near_node = tree_node.z; // left
            far_node = tree_node.w; // right
        }
        else {
            near_node = tree_node.w; // right
            far_node = tree_node.z; // left
        }

        let node_plane = bspPlanes[node];
        let denom = select(axis_direction, 1.0e-8f, abs(axis_direction) < 1.0e-8f);
        t = (node_plane - axis_origin)/denom;

        if(t > r.tmax) { node = near_node; }
        else if(t < r.tmin) { node = far_node; }
        else {
            branch_node[branch_lvl].x = i;
            branch_node[branch_lvl].y = far_node;
            branch_ray[branch_lvl].x = t;
            branch_ray[branch_lvl].y = r.tmax;
            branch_lvl++;
            r.tmax = t;
            node = near_node;
        }
    }
    return false;
}

fn intersect_min_max(r: ptr<function, Ray>) -> bool {
    let p1 = (aabb.min - r.origin)/r.direction;
    let p2 = (aabb.max - r.origin)/r.direction;
    let pmin = min(p1, p2);
    let pmax = max(p1, p2);
    let box_tmin = max(pmin.x, max(pmin.y, pmin.z)) - 1.0e-3f;
    let box_tmax = min(pmax.x, min(pmax.y, pmax.z)) + 1.0e-3f;
    if(box_tmin > box_tmax || box_tmin > r.tmax || box_tmax < r.tmin) {
        return false;
    }
    r.tmin = max(box_tmin, r.tmin);
    r.tmax = min(box_tmax, r.tmax);
    return true;
}

fn intersect_triangle(ray: Ray, hit: ptr<function, HitInfo>, triangle_idx: u32) -> bool {
    let face = meshFaces[triangle_idx];

    let v0 = attributes[face[0]].vPosition;
    let v1 = attributes[face[1]].vPosition;
    let v2 = attributes[face[2]].vPosition;

    let e0 = v1 - v0;
    let e1 = v2 - v0;
    
    let normal = cross(e0, e1);

    let dp = dot(ray.direction, normal);

    if (dp == 0) { return false;}

    let o_to_v0 = v0 - ray.origin;

    let t = dot(o_to_v0, normal) / dp;

    let cp = cross(o_to_v0, ray.direction);

    let beta = dot(cp, e1) / dp;
    let gamma = -dot(cp, e0) / dp;

    if (!((beta >= 0) & (gamma >= 0) & (beta + gamma <= 1))) { return false; }
    
    if ((ray.tmin < t) & (t < ray.tmax)) {

        let n0 = attributes[face[0]].normal;
        let n1 = attributes[face[1]].normal;
        let n2 = attributes[face[2]].normal;

        let mat_index = face[3];
        let material = materials[mat_index];

        hit.dist = t;
        hit.has_hit = true;
        hit.color = Color(material.emission, material.diffuse, vec3f(0.0));
        hit.normal = normalize((1.0 - beta - gamma) * n0 + beta * n1 + gamma * n2);
        hit.position = ray.origin + t * ray.direction;
        hit.shader = u32(uniforms.matt_shader);

        return true;
    }

    return false;
}

fn intersect_scene(r: ptr<function, Ray>, hit : ptr<function, HitInfo>) -> bool {
    
    if !intersect_min_max(r) {
        return false;
    }

    intersect_trimesh(r, hit);

    return hit.has_hit;
}

fn sample_point_light(pos: vec3f) -> Light {
    let f1 = meshFaces[u32(uniforms.lightIdx1)];
    let f2 = meshFaces[u32(uniforms.lightIdx2)];

    let v0 = attributes[f1[0]].vPosition;
    let v1 = attributes[f1[1]].vPosition;
    let v2 = attributes[f1[2]].vPosition;
    let v3 = attributes[f2[0]].vPosition;
    let v4 = attributes[f2[1]].vPosition;
    let v5 = attributes[f2[2]].vPosition;

    let n1_raw = cross(v0 - v1, v0 - v2);
    let n2_raw = cross(v3 - v4, v3 - v5);
    let a1 = length(n1_raw) * 0.5;
    let a2 = length(n2_raw) * 0.5;

    let m1 = materials[f1[3]];
    let m2 = materials[f2[3]];

    let L_e = (m1.emission + m2.emission).rgb * 0.5;
    let A = a1 + a2;

    let avg_pos = (v0 + v1 + v2 + v3 + v4 + v5) / 6.0;
    let dir = avg_pos - pos;
    let dist = length(dir);
    let n = normalize(n1_raw + n2_raw);

    let L_i = dot(n, -normalize(dir)) * (L_e * A) / (dist * dist);

    return Light(L_i, normalize(dir), dist);
}

fn sample_directional_light(pos: vec3f) -> Light {
    return Light (
    vec3f(3.14159),
    -normalize(vec3f(-1.0)),
    1000,
    );
}

fn lambertian(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
    
    let light = sample_point_light(hit.position);

    var shadow_ray = Ray(
        hit.position,
        light.w_i,
        1e-3,
        light.dist - 1e-3
    );

    var shadow_hit = HitInfo(
        false,
        hit.dist,
        hit.position + 1e-1 * hit.normal,
        hit.normal,
        Color(vec3f(0.0), vec3f(0.0), vec3f(0.0)),
        1,
        1.5,
    );

    let L_e = hit.color.ambient;

    let L_r = ((hit.color.diffuse * 0.9) / 3.14159) * light.L_i * dot(hit.normal,light.w_i);

    if (intersect_scene(&shadow_ray, &shadow_hit)) {
        return L_e;
    }

    return L_e + L_r;
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

@fragment
fn main_fs(@location(0) coords: vec2f) -> @location(0) vec4f {
    const bgcolor = vec4f(0.1, 0.3, 0.6, 1.0);
    const max_depth = 10;
    let uv = vec2f(coords.x*uniforms.aspect*0.5f, coords.y*0.5f);
    
    var result = vec3f(0.0);
    let subdivision_level = i32(uniforms.subdivision_level);

    for(var x = 0; x < subdivision_level; x++) {
        for(var y = 0; y < subdivision_level; y++) {
            let subpixel_uv = uv + jitter[x * subdivision_level + y];
            var r = get_camera_ray(subpixel_uv);
            var color = Color(vec3f(0.0), vec3f(0.0), vec3f(0.0));
            var hit = HitInfo(false, 0.0, vec3f(0.0), vec3f(0.0), color, 1, 1.0);
            for(var i = 0; i < max_depth; i++) {
                if(intersect_scene(&r, &hit)) { 
                    result += shade(&r, &hit);

                } else {
                    result += bgcolor.rgb;
                    break;
                }
                if(hit.has_hit) { break; }
            }
        }
    }
    
    result /= uniforms.subdivision_level * uniforms.subdivision_level;
    
    return vec4f(pow(result, vec3f(1.0/uniforms.gamma)), bgcolor.a);
}