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

//insipration https://eh-dub.github.io/woobles/
//

pub fn remap(value: f32, from_min: f32, from_max: f32, to_min: f32, to_max: f32) f32 {
    return (value - from_min) * (to_max - to_min) / (from_max - from_min) + to_min;
}

pub fn createCirclePrimitive(
    allocator: std.mem.Allocator,
    vertices: u32,
    radius: f32,
    time: f32,
    repeat: u32,
) !Primitive {
    const vertex_count = (vertices * 2 + 1) * repeat;
    var vertex_data = try std.ArrayList(VertexData).initCapacity(allocator, vertex_count);

    const index_count = ((vertices + 1) * 3 * 2 * 2) * repeat;
    var index_data = try std.ArrayList(u32).initCapacity(allocator, index_count);

    const line_widgth = 0.005;

    var x: u32 = 0;

    var iter: u32 = 0;

    while (iter < repeat) : (iter += 1) {
        var iter_offset = iter * (vertices * 2);
        if (iter_offset > 0) iter_offset -= 1;
        const angle = 2 * PI / @as(f32, @floatFromInt(vertices));

        const repeat_f = @as(f32, @floatFromInt(repeat));

        const frequency: f32 = remap(@as(f32, @floatFromInt(iter)), 0, repeat_f - 1, 2, 4);
        const phase: f32 = time;

        x = iter_offset;

        while (x < vertices + iter_offset) : (x += 1) {
            const x_f = @as(f32, @floatFromInt(x));
            const r_f = @as(f32, @floatFromInt(repeat));
            const original_radius = remap(@as(f32, @floatFromInt(iter)), 0, r_f, 0.01, radius);
            const magnitude: f32 = original_radius / 75;

            const current_angle = angle * x_f;
            const wobbly_function: f32 = zmath.cos(frequency * current_angle + phase);
            const modified_radius = original_radius + magnitude * wobbly_function;

            const out_pos_x = modified_radius * zmath.cos(angle * x_f);
            const out_pos_y = modified_radius * zmath.sin(angle * x_f);
            vertex_data.appendAssumeCapacity(VertexData{
                .position = F32x3{ out_pos_x, out_pos_y, 0.0 },
                .normal = F32x3{ out_pos_x, out_pos_y, 0.0 },
            });

            const inner_radius = modified_radius - line_widgth;

            const inner_pos_x = inner_radius * zmath.cos(angle * x_f);
            const inner_pos_y = inner_radius * zmath.sin(angle * x_f);
            vertex_data.appendAssumeCapacity(VertexData{
                .position = F32x3{ inner_pos_x, inner_pos_y, 0.0 },
                .normal = F32x3{ inner_pos_x, inner_pos_y, 0.0 },
            });
        }

        x = iter_offset;
        if (iter_offset > 0) x += 1;

        while (x < ((vertices * 2) - 1 + iter_offset)) : (x += 1) {
            index_data.appendAssumeCapacity(x);
            index_data.appendAssumeCapacity(x + 1);
            index_data.appendAssumeCapacity(x + 2);
            index_data.appendAssumeCapacity(x);
            index_data.appendAssumeCapacity(x + 2);
            index_data.appendAssumeCapacity(x + 1);
        }

        x = iter_offset;
        if (iter_offset > 0) x += 1;

        const last_index = vertices * 2 - 1;
        index_data.appendAssumeCapacity(x);
        index_data.appendAssumeCapacity(x + 1);
        index_data.appendAssumeCapacity(last_index + x);
        index_data.appendAssumeCapacity(x);
        index_data.appendAssumeCapacity(last_index + x);
        index_data.appendAssumeCapacity(last_index + x - 1);
        x = 0;
    }

    return Primitive{
        .vertex_data = vertex_data,
        .vertex_count = vertex_count,
        .index_data = index_data,
        .index_count = index_count,
    };
}
