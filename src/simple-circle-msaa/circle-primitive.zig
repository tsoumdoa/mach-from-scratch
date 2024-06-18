const std = @import("std");
const zmath = @import("zmath.zig");
const PI = 3.1415927410125732421875;

pub const F32x3 = @Vector(3, f32);
pub const F32x4 = @Vector(4, f32);
pub const VertexData = struct {
    position: F32x3,
    normal: F32x3,
};

pub const Primitive = struct {
    vertex_data: std.ArrayList(VertexData),
    vertex_count: u32,
    index_data: std.ArrayList(u32),
    index_count: u32,
};

pub fn createCirclePrimitive(allocator: std.mem.Allocator, vertices: u32, radius: f32) !Primitive {
    const vertex_count = vertices + 1;
    var vertex_data = try std.ArrayList(VertexData).initCapacity(allocator, vertex_count);

    // Mid point of circle
    vertex_data.appendAssumeCapacity(VertexData{ .position = F32x3{ 0, 0, 0.0 }, .normal = F32x3{ 0, 0, 0.0 } });

    var x: u32 = 0;
    const angle = 2 * PI / @as(f32, @floatFromInt(vertices));
    // var prng = std.rand.DefaultPrng.init(blk: {
    //     var seed: u64 = undefined;
    //     try std.posix.getrandom(std.mem.asBytes(&seed));
    //     break :blk seed;
    // });
    // const rand = prng.random();
    while (x < vertices) : (x += 1) {
        // var ran = rand.float(f32);
        // ran = 0.95 + 0.05 * ran;
        const x_f = @as(f32, @floatFromInt(x));
        // const pos_x = radius * zmath.cos(angle * x_f) * ran;
        // const pos_y = radius * zmath.sin(angle * x_f) * ran;
        const pos_x = radius * zmath.cos(angle * x_f);
        const pos_y = radius * zmath.sin(angle * x_f);

        vertex_data.appendAssumeCapacity(VertexData{ .position = F32x3{ pos_x, pos_y, 0.0 }, .normal = F32x3{ pos_x, pos_y, 0.0 } });
    }

    const index_count = (vertices + 1) * 3;
    var index_data = try std.ArrayList(u32).initCapacity(allocator, index_count);

    x = 1;
    while (x <= vertices) : (x += 1) {
        index_data.appendAssumeCapacity(0);
        index_data.appendAssumeCapacity(x);
        index_data.appendAssumeCapacity(x + 1);
    }

    index_data.appendAssumeCapacity(0);
    index_data.appendAssumeCapacity(vertices);
    index_data.appendAssumeCapacity(1);

    return Primitive{
        .vertex_data = vertex_data,
        .vertex_count = vertex_count,
        .index_data = index_data,
        .index_count = index_count,
    };
}
