"use strict";
window.onload = function () { main(); }
async function main() {
    const gpu = navigator.gpu;
    const adapter = await gpu.requestAdapter();
    const device = await adapter.requestDevice();
    const canvas = document.getElementById('canvas');
    const context = canvas.getContext('webgpu');
    const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
    context.configure({
        device: device,
        format: canvasFormat,
    });

    const wgslfile = document.getElementById('wgsl').src;
    const wgslcode = await fetch(wgslfile, { cache: "reload" }).then(r => r.text());
    const wgsl = device.createShaderModule({
        code: wgslcode
    });

    const pipeline = device.createRenderPipeline({
        layout: 'auto',
        vertex: {
            module: wgsl,
            entryPoint: 'main_vs',
            //buffers: [vertexBufferLayout],
        },
        fragment: {
            module: wgsl,
            entryPoint: 'main_fs',
            targets: [{ format: canvasFormat }],
        },
        primitive: { topology: 'triangle-strip', },
    });

    let n_vec4 = 24;
    let bytelength = n_vec4 * sizeof['vec4']; // Buffers are allocated in vec4 chunks
    let uniforms = new ArrayBuffer(bytelength);

    const texture = await load_texture(device, "../grass.jpg");

    const uniformBuffer = device.createBuffer({
        size: uniforms.byteLength,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    const bindGroup = device.createBindGroup({
        layout: pipeline.getBindGroupLayout(0),
        entries: [{
            binding: 0,
            resource: { buffer: uniformBuffer }
        },
        { binding: 1, resource: texture.createView() },
        ],
    });

    const eyepos = vec3(2.0, 1.5, 2.0);
    const lookat = vec3(0.0, 0.5, 0.0);
    const up = vec3(0.0, 1.0, 0.0);

    let user_inputs = {
        cam_const: 1,
        matt_shader: 1,
        glass_shader: 5,
        texture_lookup: 0,
        texture_filtering: 1,
        texturing: 1,
    };

    const aspect = canvas.width / canvas.height;
    const gamma = 1.2;

    const viewdir = normalize(subtract(lookat, eyepos));
    const b1 = normalize(cross(viewdir, up));
    const b2 = cross(b1, viewdir);

    function render() {

        new Float32Array(uniforms, 0, n_vec4 * 4).set([
            aspect,
            user_inputs.cam_const,
            gamma,
            user_inputs.texturing,
            //
            user_inputs.matt_shader,
            user_inputs.glass_shader,
            user_inputs.texture_lookup,
            user_inputs.texture_filtering,
            //
            ...eyepos, 0.0,
            ...b1, 0.0,
            ...b2, 0.0,
            ...viewdir, 0.0,
            // scene
            // plane
            ...vec3(0.0, 0.0, 0.0), 0.0,
            ...vec3(0.0, 1.0, 0.0), 0.0,
            ...vec3(0.01, 0.07, 0.0), 0.0,
            ...vec3(0.09, 0.63, 0.0), 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            // triangle
            ...vec3(-0.2, 0.1, 0.9), 0.0,
            ...vec3(0.2, 0.1, 0.9), 0.0,
            ...vec3(-0.2, 0.1, -0.1), 0.0,
            ...vec3(0.04, 0.03, 0.02), 0.0,
            ...vec3(0.36, 0.27, 0.18), 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            // sphere
            ...vec3(0.0, 0.5, 0.0), 0.0,
            0.3, 1.5, 42.0, 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            ...vec3(0.1, 0.1, 0.1), 0.0,
            // light
            ...vec3(0.0, 1.0, 0.0), 0.0,
            ...vec3(3.14, 3.14, 3.14), 0.0,
        ]);
        device.queue.writeBuffer(uniformBuffer, 0, uniforms);

        // Create a render pass in a command buffer and submit it
        const encoder = device.createCommandEncoder();
        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                view: context.getCurrentTexture().createView(),
                loadOp: "clear",
                storeOp: "store",
            }]
        });

        pass.setBindGroup(0, bindGroup)

        pass.setPipeline(pipeline);
        pass.draw(4);

        pass.end();
        device.queue.submit([encoder.finish()]);

    }

    function addSliderCallback(name, variable) {
        var elem = document.getElementById(name + "SliderValue");
        document.getElementById(name + "Slider").addEventListener("input", (event) => {
            let newVal = event.target.value;
            user_inputs[variable] = newVal;
            elem.textContent = newVal;
            render();
        })
    }

    addSliderCallback("cameraConstant", "cam_const");

    function addSelectCallback(name, variable) {
        document.getElementById(name + "Select").addEventListener("input", (event) => {
            let newVal = event.target.value;
            user_inputs[variable] = newVal;
            render();
        })
    }

    addSelectCallback("mattShader", "matt_shader");
    addSelectCallback("glassShader", "glass_shader");
    addSelectCallback("textureLookup", "texture_lookup");
    addSelectCallback("textureFilter", "texture_filtering");
    addSelectCallback("texturing", "texturing");

    render();
}

async function load_texture(device, filename) {
    const response = await fetch(filename);
    const blob = await response.blob();
    const img = await createImageBitmap(blob, { colorSpaceConversion: 'none' });
    const texture = device.createTexture({
        size: [img.width, img.height, 1],
        format: "rgba8unorm",
        usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
    });
    device.queue.copyExternalImageToTexture(
        { source: img, flipY: true },
        { texture: texture },
        { width: img.width, height: img.height },
    );
    return texture;
}