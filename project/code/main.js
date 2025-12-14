"use strict";
window.onload = function () { main(); }
async function main() {
    const gpu = navigator.gpu;
    const adapter = await gpu.requestAdapter();
    const canTimestamp = adapter.features.has('timestamp-query');
    const device = await adapter.requestDevice({
        requiredFeatures: (canTimestamp ? ['timestamp-query'] : []),
    });
    const timingHelper = new TimingHelper(device);
    let gpuTime = 0;
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
            targets: [{ format: canvasFormat }, { format: 'rgba32float' }],
        },
        primitive: { topology: 'triangle-strip', },
    });

    let n_vec4 = 25;
    let bytelength = n_vec4 * sizeof['vec4']; // Buffers are allocated in vec4 chunks
    let uniforms = new ArrayBuffer(bytelength);


    let textures = new Object();
    textures.width = canvas.width;
    textures.height = canvas.height;
    textures.renderSrc = device.createTexture({
        size: [canvas.width, canvas.height],
        usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC,
        format: 'rgba32float',
    });
    textures.renderDst = device.createTexture({
        size: [canvas.width, canvas.height],
        usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
        format: 'rgba32float',
    });

    console.log(textures);

    // uniforms    
    const uniformBuffer = device.createBuffer({
        size: uniforms.byteLength,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    // precomputed jitters
    let jitter = new Float32Array(200); // allowing subdivs from 1 to 10
    const jitterBuffer = device.createBuffer({
        size: jitter.byteLength,
        usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
    });

    // object
    const obj_filename = '../../objects/bunnybox.obj';
    const obj = await readOBJFile(obj_filename, 1, true); // file name, scale, ccw vertices

    console.log(obj);

    let buffers = {};

    build_bsp_tree(obj, device, buffers);

    console.log(buffers)
 
    let mat_bytelength = obj.materials.length * 2 * sizeof['vec4'];
    var materials = new ArrayBuffer(mat_bytelength);
    const materialBuffer = device.createBuffer({
        size: mat_bytelength,
        usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE,
    });
    for (var i = 0; i < obj.materials.length; ++i) {
        const mat = obj.materials[i];
        const emission = vec4(mat.emission.r, mat.emission.g, mat.emission.b, mat.emission.a);
        const color = vec4(mat.color.r, mat.color.g, mat.color.b, mat.color.a);
        new Float32Array(materials, i * 2 * sizeof['vec4'], 8).set([...emission, ...color]);
    }
    device.queue.writeBuffer(materialBuffer, 0, materials);


    const bindGroup = device.createBindGroup({
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            {
                binding: 0,
                resource: { buffer: uniformBuffer },
            },
            {
                binding: 1,
                resource: textures.renderDst.createView(),
            },
            {
                binding: 3,
                resource: { buffer: buffers.attribs },
            },
            {
                binding: 4,
                resource: { buffer: buffers.indices },
            },
            {
                binding: 5,
                resource: { buffer: materialBuffer },
            },
            {
                binding: 6,
                resource: { buffer: buffers.aabb },
            },
            {
                binding: 7,
                resource: { buffer: buffers.bspPlanes },
            },
            {
                binding: 8,
                resource: { buffer: buffers.bspTree },
            },
            {
                binding: 9,
                resource: { buffer: buffers.treeIds },
            },

        ],
    });

    const eyepos = vec3(27.7, 27.5, -57.0);
    const lookat = vec3(27.7, 27.5, 0.0);
    const up = vec3(0.0, 1.0, 0.0);

    var background_color = vec3(0.1, 0.3, 0.6);

    let user_inputs = {
        cam_const: 1,
        matt_shader: 1,
        glass_shader: 5,
        texture_lookup: 0,
        texture_filtering: 1,
        texturing: 1,
        subdivision_level: 1,
        texture_magnification: 1,
    };

    const aspect = canvas.width / canvas.height;
    const gamma = 1.5;

    const viewdir = normalize(subtract(lookat, eyepos));
    const b1 = normalize(cross(viewdir, up));
    const b2 = cross(b1, viewdir);

    var frame = 0.0;
    var progressive_rendering = true;

    function render() {

        new Float32Array(uniforms, 0, n_vec4 * 4).set([
            aspect,
            user_inputs.cam_const,
            gamma,
            frame,
            //
            user_inputs.matt_shader,
            user_inputs.glass_shader,
            user_inputs.texture_lookup,
            user_inputs.texture_filtering,
            //
            user_inputs.subdivision_level,
            user_inputs.texture_magnification,
            obj.light_indices[0],
            obj.light_indices[1],
            //
            ...eyepos, 0.0,
            ...b1, 0.0,
            ...b2, 0.0,
            ...viewdir, 0.0,
            ...background_color, 0.0,
            // scene
            // sphere1
            ...vec3(15.0, 35.0, 42.0), 3.0,
            9.0, 1.5, 42.0, 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            ...vec3(0.1, 0.1, 0.1), 0.0,            
            // sphere2
            ...vec3(42.0, 9.0, 10.0), 4.0,
            9.0, 1.5, 42.0, 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            ...vec3(0.0, 0.0, 0.0), 0.0,
            ...vec3(0.1, 0.1, 0.1), 0.0,
        ]);
        device.queue.writeBuffer(uniformBuffer, 0, uniforms);

        compute_jitters(jitter, 1 / canvas.height, user_inputs.subdivision_level);
        device.queue.writeBuffer(jitterBuffer, 0, jitter);


        // Create a render pass in a command buffer and submit it
        const encoder = device.createCommandEncoder();
        const pass = timingHelper.beginRenderPass(encoder, {
            colorAttachments: [
                {
                    view: context.getCurrentTexture().createView(),
                    loadOp: "clear",
                    storeOp: "store",
                },
                {
                    view: textures.renderSrc.createView(),
                    loadOp: "load",
                    storeOp: "store"
                }
            ]
        });

        pass.setBindGroup(0, bindGroup)

        pass.setPipeline(pipeline);
        pass.draw(4);

        pass.end();

        encoder.copyTextureToTexture(
            { texture: textures.renderSrc },
            { texture: textures.renderDst },
            [textures.width, textures.height]
        );

        device.queue.submit([encoder.finish()]);

        frame += 1;

        timingHelper.getResult().then(time => {
            console.log('Frame:', frame);
            gpuTime = time / 1000;
            console.log('GPU Time:', gpuTime);
            if (frame < 250 && progressive_rendering) render();
        });

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
    addSliderCallback("subdivisionLevel", "subdivision_level");

    function addSelectCallback(name, variable) {
        document.getElementById(name + "Select").addEventListener("input", (event) => {
            let newVal = event.target.value;
            user_inputs[variable] = newVal;
            render();
        })
    }

    addSelectCallback("mattShader", "matt_shader");

    const progressiveToggle = document.getElementById("progressiveToggle");

    progressiveToggle.addEventListener("change", (e) => {
        progressive_rendering = e.target.checked;

        if (progressive_rendering) {
            render();
        }
    });

    const backgroundToggle = document.getElementById("backgroundToggle");

    backgroundToggle.addEventListener("change", (e) => {
        if (e.target.checked) {
            background_color = vec3(0.0, 0.0, 0.0);
        } else {
            background_color = vec3(0.1, 0.3, 0.6);
        }

        frame = 0.0;
        render();
    });


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

function compute_jitters(jitter, pixelsize, subdivs) {
    const step = pixelsize / subdivs;
    if (subdivs < 2) {
        jitter[0] = 0.0;
        jitter[1] = 0.0;
    }
    else {
        for (var i = 0; i < subdivs; ++i)
            for (var j = 0; j < subdivs; ++j) {
                const idx = (i * subdivs + j) * 2;
                jitter[idx] = (Math.random() + j) * step - pixelsize * 0.5;
                jitter[idx + 1] = (Math.random() + i) * step - pixelsize * 0.5;
            }
    }
}