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

// Define Ray struct
struct Ray {
    origin: vec3f,
    direction: vec3f,
    tmin: f32,
    tmax: f32
};

fn get_camera_ray(ipcoords: vec2f) -> Ray {
    // Implement ray generation (WGSL has vector operations like normalize and cross)
    
    // define orthonormal basis
    // could be calculated by defining e, p, u, etc.
    let b1 = vec3f(1.0, 0.0, 0.0);
    let b2 = vec3f(0.0, 1.0, 0.0);
    let vd = vec3f(0.0, 0.0, 1.0);

    // ray in camera basis, then normalize
    let q = b1 * ipcoords.x + b2 * ipcoords.y + vd * 0.1;
    let w = normalize(q);

    var ray: Ray;
    ray.origin = vec3f(0.0, 0.0, 0.0);
    ray.direction = w;
    ray.tmin = 0.0;
    ray.tmax = 1e30;
    return ray;
}

@fragment
fn main_fs(@location(0) coords: vec2f) -> @location(0) vec4f {
    let ipcoords = coords*0.5;
    var r = get_camera_ray(ipcoords);
    return vec4f(r.direction*0.5 + 0.5, 1.0);
}