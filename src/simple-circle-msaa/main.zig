const std = @import("std");
const mach = @import("mach");
const core = mach.core;
const gpu = mach.gpu;

const renderer = @import("renderer.zig");

pub const App = @This();
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

title_timer: core.Timer,

pub fn init(app: *App) !void {
    try core.init(.{ .required_limits = gpu.Limits{
        .max_vertex_buffers = 1,
        .max_vertex_attributes = 2,
        .max_bind_groups = 1,
        .max_uniform_buffers_per_shader_stage = 1,
        .max_uniform_buffer_binding_size = 16 * 1 * @sizeOf(f32),
    } });

    const allocator = gpa.allocator();
    const timer = try core.Timer.start();
    try renderer.init(allocator, timer);
    app.* = .{ .title_timer = try core.Timer.start() };
}

pub fn deinit(app: *App) void {
    _ = app;
    defer _ = gpa.deinit();
    defer core.deinit();
    defer renderer.deinit();
}

pub fn update(app: *App) !bool {
    renderer.update();

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
