const std = @import("std");

const mach = @import("mach");
const core = mach.core;
const gpu = mach.gpu;

const zm = @import("zmath.zig");
const primitives = @import("circle-primitive.zig");
const Primitive = primitives.Primitive;
const VertexData = primitives.VertexData;

pub const Renderer = @This();

var app_allocator: std.mem.Allocator = undefined;
var queue: *gpu.Queue = undefined;
var pipeline: *gpu.RenderPipeline = undefined;
var app_timer: core.Timer = undefined;
var color_texture: *gpu.Texture = undefined;
var color_texture_view: *gpu.TextureView = undefined;
var depth_texture: *gpu.Texture = undefined;
var depth_texture_view: *gpu.TextureView = undefined;

const SAMPLE_COUNT = 4;

const PrimitiveRenderData = struct {
    vertex_buffer: *gpu.Buffer,
    index_buffer: *gpu.Buffer,
    vertex_count: u32,
    index_count: u32,
};

const UniformBufferObject = struct {
    screen_size: @Vector(2, f32),
};

var uniform_buffer: *gpu.Buffer = undefined;
var bind_group: *gpu.BindGroup = undefined;
var primitives_data: PrimitiveRenderData = undefined;

fn createBindGroupLayout() *gpu.BindGroupLayout {
    return core.device.createBindGroupLayout(
        &gpu.BindGroupLayout.Descriptor.init(.{
            .entries = &.{gpu.BindGroupLayout.Entry.buffer(
                0,
                .{ .vertex = true, .fragment = false },
                .uniform,
                true,
                0,
            )},
        }),
    );
}

fn createVertexBuffer(primitive: Primitive) *gpu.Buffer {
    const vertex_buffer = core.device.createBuffer(&gpu.Buffer.Descriptor{
        .size = primitive.vertex_count * @sizeOf(VertexData),
        .usage = .{ .vertex = true, .copy_dst = true },
        .mapped_at_creation = .false,
    });
    queue.writeBuffer(vertex_buffer, 0, primitive.vertex_data.items[0..]);

    return vertex_buffer;
}

fn createIndexBuffer(primitive: Primitive) *gpu.Buffer {
    const index_buffer_descriptor = gpu.Buffer.Descriptor{
        .size = primitive.index_count * @sizeOf(u32),
        .usage = .{ .index = true, .copy_dst = true },
        .mapped_at_creation = .false,
    };
    const index_buffer = core.device.createBuffer(&index_buffer_descriptor);
    queue.writeBuffer(index_buffer, 0, primitive.index_data.items[0..]);

    return index_buffer;
}

fn createPipeline(
    shader_module: *gpu.ShaderModule,
    bind_group_layout: *gpu.BindGroupLayout,
) *gpu.RenderPipeline {
    const pipeline_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &[_]*gpu.BindGroupLayout{bind_group_layout},
    }));
    defer pipeline_layout.release();

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .label = "Main Pipeline",
        .layout = pipeline_layout,
        .vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vertex_main",
            .buffers = &.{gpu.VertexBufferLayout.init(.{
                .array_stride = @sizeOf(VertexData),
                .step_mode = .vertex,
                .attributes = &[_]gpu.VertexAttribute{
                    .{ .format = .float32x3, .shader_location = 0, .offset = 0 },
                    .{ .format = .float32x3, .shader_location = 1, .offset = @sizeOf(primitives.F32x3) },
                },
            })},
        }),
        .primitive = gpu.PrimitiveState{
            .topology = .triangle_list,
            .front_face = .ccw,
            .cull_mode = .back,
        },
        .depth_stencil = &gpu.DepthStencilState{
            .format = .depth24_plus,
            .depth_write_enabled = .true,
            .depth_compare = .less,
        },
        .multisample = gpu.MultisampleState{
            .count = SAMPLE_COUNT,
            .mask = 0xFFFFFFFF,
            .alpha_to_coverage_enabled = .false,
        },
        .fragment = &gpu.FragmentState.init(.{
            .module = shader_module,
            .entry_point = "frag_main",
            .targets = &.{gpu.ColorTargetState{
                .format = core.descriptor.format,
                .blend = &gpu.BlendState{
                    .color = gpu.BlendComponent{
                        .operation = .add,
                        .src_factor = .src_alpha,
                        .dst_factor = .one_minus_src_alpha,
                    },
                    .alpha = gpu.BlendComponent{
                        .operation = .add,
                        .src_factor = .zero,
                        .dst_factor = .one,
                    },
                },
                .write_mask = gpu.ColorWriteMaskFlags.all,
            }},
        }),
    };

    return core.device.createRenderPipeline(&pipeline_descriptor);
}

fn createTexture() void {
    color_texture = core.device.createTexture(&gpu.Texture.Descriptor{
        .usage = .{ .render_attachment = true },
        .size = .{
            .width = core.descriptor.width,
            .height = core.descriptor.height,
            .depth_or_array_layers = 1,
        },
        .format = core.descriptor.format,
        .sample_count = SAMPLE_COUNT,
    });

    color_texture_view = color_texture.createView(null);

    depth_texture = core.device.createTexture(&gpu.Texture.Descriptor{
        .usage = .{ .render_attachment = true },
        .size = .{
            .width = core.descriptor.width,
            .height = core.descriptor.height,
            .depth_or_array_layers = 1,
        },
        .format = .depth24_plus,
        .sample_count = SAMPLE_COUNT,
    });

    depth_texture_view = depth_texture.createView(null);
}

fn createBindBuffer(bind_group_layout: *gpu.BindGroupLayout) void {
    uniform_buffer = core.device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(UniformBufferObject),
        .mapped_at_creation = .false,
    });

    bind_group = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = bind_group_layout,
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)),
            },
        }),
    );
}

pub fn init(allocator: std.mem.Allocator, timer: core.Timer) !void {
    queue = core.queue;
    app_timer = timer;
    app_allocator = allocator;

    {
        const circle_primitive =
            try primitives.createCirclePrimitive(allocator, 128, 0.8, app_timer.read());
        // try primitives.createCirclePrimitive(allocator, 64, 0.8);

        primitives_data =
            PrimitiveRenderData{
            .vertex_buffer = createVertexBuffer(circle_primitive),
            .index_buffer = createIndexBuffer(circle_primitive),
            .vertex_count = circle_primitive.vertex_count,
            .index_count = circle_primitive.index_count,
        };

        defer circle_primitive.vertex_data.deinit();
        defer circle_primitive.index_data.deinit();

        var bind_group_layout = createBindGroupLayout();
        defer bind_group_layout.release();

        createBindBuffer(bind_group_layout);

        var shader = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
        defer shader.release();

        pipeline = createPipeline(shader, bind_group_layout);
    }
    createTexture();
}

pub fn deinit() void {
    primitives_data.vertex_buffer.release();
    primitives_data.index_buffer.release();
    bind_group.release();
    uniform_buffer.release();
    depth_texture.release();
    color_texture.release();
    color_texture_view.release();
    depth_texture_view.release();
    pipeline.release();
}

pub fn update() !void {
    var iter = core.pollEvents();

    while (iter.next()) |event| {
        switch (event) {
            .framebuffer_resize => |_| {
                depth_texture.release();
                depth_texture_view.release();
                color_texture.release();
                color_texture_view.release();
                createTexture();
            },
            .close => return,
            else => {},
        }
    }

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = color_texture_view,
        .resolve_target = back_buffer_view,
        .clear_value = gpu.Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0 },
        // .clear_value = std.mem.zeroes(gpu.Color),
        .load_op = .clear,
        .store_op = .store,
    };
    const depth_stencil_attachment = gpu.RenderPassDepthStencilAttachment{
        .view = depth_texture_view,
        .depth_load_op = .clear,
        .depth_store_op = .store,
        .depth_clear_value = 1.0,
    };

    const encoder = core.device.createCommandEncoder(null);
    const render_pass_info = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
        .depth_stencil_attachment = &depth_stencil_attachment,
    });

    const width = @as(f32, @floatFromInt(core.size().width));
    const height = @as(f32, @floatFromInt(core.size().height));

    const ubo = UniformBufferObject{
        .screen_size = .{ width, height },
    };
    encoder.writeBuffer(uniform_buffer, 0, &[_]UniformBufferObject{ubo});

    {
        const time = app_timer.read();
        const circle_primitive =
            try primitives.createCirclePrimitive(app_allocator, 128, 0.8, time);

        primitives_data =
            PrimitiveRenderData{
            .vertex_buffer = createVertexBuffer(circle_primitive),
            .index_buffer = createIndexBuffer(circle_primitive),
            .vertex_count = circle_primitive.vertex_count,
            .index_count = circle_primitive.index_count,
        };

        defer circle_primitive.vertex_data.deinit();
        defer circle_primitive.index_data.deinit();
    }

    const pass = encoder.beginRenderPass(&render_pass_info);
    pass.setPipeline(pipeline);

    const vertex_buffer = primitives_data.vertex_buffer;
    const vertex_count = primitives_data.vertex_count;

    pass.setVertexBuffer(0, vertex_buffer, 0, @sizeOf(VertexData) * vertex_count);
    pass.setBindGroup(0, bind_group, &.{0});

    const index_buffer = primitives_data.index_buffer;
    const index_count = primitives_data.index_count;

    pass.setIndexBuffer(index_buffer, .uint32, 0, @sizeOf(u32) * index_count);
    pass.drawIndexed(index_count, 1, 0, 0, 0);
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    queue.submit(&[_]*gpu.CommandBuffer{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();
}
