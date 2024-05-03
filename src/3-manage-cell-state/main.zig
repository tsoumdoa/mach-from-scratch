const std = @import("std");
const mach = @import("mach");
const core = mach.core;
const gpu = mach.gpu;

const Vertex = extern struct {
    pos: @Vector(2, f32),
    col: @Vector(3, f32),
};

const UniformBufferObject = extern struct {
    grid: @Vector(2, f32),
};

const StorageBufferObject = struct {
    cell_state_array: [grid_size * grid_size]u32,
};

const vertices = [_]Vertex{
    .{ .pos = .{ -0.8, -0.8 }, .col = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.8, -0.8 }, .col = .{ 0, 1, 0 } },
    .{ .pos = .{ 0.8, 0.8 }, .col = .{ 0, 0, 1 } },
    .{ .pos = .{ -0.8, 0.8 }, .col = .{ 1, 1, 1 } },
};
const grid_size = 32;
const grid = UniformBufferObject{ .grid = .{ grid_size, grid_size } };
var sbo_cell_state = StorageBufferObject{ .cell_state_array = std.mem.zeroes([grid_size * grid_size]u32) };

const index_data = [_]u32{ 0, 1, 2, 2, 3, 0 };

const update_interval = 0.5;
var step: usize = 0;

pub const App = @This();
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

title_timer: core.Timer,
timer: core.Timer,
pipeline: *gpu.RenderPipeline,
uniform_buffer: *gpu.Buffer,
sbf_cell_state_a: *gpu.Buffer,
sbf_cell_state_b: *gpu.Buffer,
vertex_buffer: *gpu.Buffer,
index_buffer: *gpu.Buffer,
bind_group_a: *gpu.BindGroup,
bind_group_b: *gpu.BindGroup,

pub fn init(app: *App) !void {

    //some boiler plate code
    try core.init(.{});
    const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    const size = core.Size{ .width = 500, .height = 500 };
    core.setSize(size);

    //vertex attribute
    const vertex_attributes = [_]gpu.VertexAttribute{
        .{ .format = .float32x2, .offset = @offsetOf(Vertex, "pos"), .shader_location = 0 },
        .{ .format = .float32x3, .offset = @offsetOf(Vertex, "col"), .shader_location = 1 },
    };

    const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(Vertex),
        .step_mode = .vertex,
        .attributes = &vertex_attributes,
    });

    //fragment shader
    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &.{},
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    //uniform buffer
    const uniform_buffer = core.device.createBuffer(&.{
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(UniformBufferObject),
        .mapped_at_creation = .false,
    });

    //srorage buffer
    const sbf_cell_state_a = core.device.createBuffer(&.{
        .label = "Cell State A",
        .usage = .{ .storage = true, .copy_dst = true },
        .size = @sizeOf(StorageBufferObject),
        .mapped_at_creation = .false,
    });
    const sbf_cell_state_b = core.device.createBuffer(&.{
        .label = "Cell State B",
        .usage = .{ .storage = true, .copy_dst = true },
        .size = @sizeOf(StorageBufferObject),
        .mapped_at_creation = .false,
    });

    const bgle_uniform = gpu.BindGroupLayout.Entry
        .buffer(0, .{
        .vertex = true,
    }, .uniform, false, 0);
    const bgle_storage = gpu.BindGroupLayout.Entry
        .buffer(1, .{
        .vertex = true,
        .compute = true,
    }, .read_only_storage, false, 0);
    const bgl = core.device.createBindGroupLayout(
        &gpu.BindGroupLayout.Descriptor.init(.{
            .entries = &.{ bgle_uniform, bgle_storage },
        }),
    );

    //bind groups
    const bind_group_layouts = [_]*gpu.BindGroupLayout{bgl};

    const bind_group_a = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = bgl,
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.buffer(1, sbf_cell_state_a, 0, @sizeOf(StorageBufferObject)),
            },
        }),
    );

    const bind_group_b = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = bgl,
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.buffer(1, sbf_cell_state_b, 0, @sizeOf(StorageBufferObject)),
            },
        }),
    );

    //pipeline layout
    const pipeline_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &bind_group_layouts,
    }));

    defer pipeline_layout.release();

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vertex_main",
            .buffers = &.{vertex_buffer_layout},
        }),
        .primitive = .{ .cull_mode = .back },
    };

    //vertexbuffer
    const vertex_buffer = core.device.createBuffer(&.{
        .usage = .{ .vertex = true },
        .size = @sizeOf(Vertex) * vertices.len,
        .mapped_at_creation = .true,
    });
    const vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertices.len);
    @memcpy(vertex_mapped.?, vertices[0..]);
    vertex_buffer.unmap();

    //index buffer
    const index_buffer = core.device.createBuffer(&.{
        .usage = .{ .index = true },
        .size = @sizeOf(u32) * index_data.len,
        .mapped_at_creation = .true,
    });
    const index_mapped = index_buffer.getMappedRange(u32, 0, index_data.len);
    @memcpy(index_mapped.?, index_data[0..]);
    index_buffer.unmap();

    // bind the app
    app.* = .{
        .title_timer = try core.Timer.start(),
        .timer = try core.Timer.start(),
        .pipeline = core.device.createRenderPipeline(&pipeline_descriptor),
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .uniform_buffer = uniform_buffer,
        .sbf_cell_state_a = sbf_cell_state_a,
        .sbf_cell_state_b = sbf_cell_state_b,
        .bind_group_a = bind_group_a,
        .bind_group_b = bind_group_b,
    };
}

pub fn deinit(app: *App) void {
    app.vertex_buffer.release();
    app.index_buffer.release();
    app.pipeline.release();
    app.uniform_buffer.release();
    app.sbf_cell_state_a.release();
    app.sbf_cell_state_a.release();
    app.bind_group_a.release();
    app.bind_group_b.release();
    core.deinit();
    _ = gpa.deinit();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| if (event == .close) return true;

    if (app.timer.read() >= update_interval) {
        app.timer.reset();
        const res = try updateGrid(app);
        _ = res;
    }

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("RGB Quad [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}

const stdout = std.io.getStdOut().writer();
fn updateGrid(app: *App) !bool {
    step += 1;
    var cell = &sbo_cell_state.cell_state_array;
    var i: u32 = 0;

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    const encoder = core.device.createCommandEncoder(null);
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        .load_op = .clear,
        .store_op = .store,
    };
    const render_pass_info = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });

    encoder.writeBuffer(app.uniform_buffer, 0, &[_]UniformBufferObject{grid});

    if (step % 2 == 0) {
        while (i < cell.len) {
            if (i % 3 == 0) {
                cell[i] = 1;
            } else {
                cell[i] = 0;
            }
            i += 1;
        }
        encoder.writeBuffer(app.sbf_cell_state_a, 0, &[_]StorageBufferObject{sbo_cell_state});
    } else {
        while (i < cell.len) {
            if (i % 2 == 0) {
                cell[i] = 1;
            } else {
                cell[i] = 0;
            }
            i += 1;
        }
        encoder.writeBuffer(app.sbf_cell_state_b, 0, &[_]StorageBufferObject{sbo_cell_state});
    }
    i = 0;

    const pass = encoder.beginRenderPass(&render_pass_info);
    pass.setPipeline(app.pipeline);
    pass.setVertexBuffer(0, app.vertex_buffer, 0, @sizeOf(Vertex) * vertices.len);
    pass.setIndexBuffer(app.index_buffer, .uint32, 0, @sizeOf(u32) * index_data.len);
    if (step % 2 == 0) {
        pass.setBindGroup(0, app.bind_group_a, &.{});
    } else {
        pass.setBindGroup(0, app.bind_group_b, &.{});
    }
    pass.drawIndexed(index_data.len, grid_size * grid_size, 0, 0, 0);

    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();
    core.queue.submit(&.{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();

    return false;
}
