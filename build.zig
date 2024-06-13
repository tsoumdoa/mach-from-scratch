const std = @import("std");
const mach = @import("mach");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const mach_dep = b.dependency("mach", .{
        .target = target,
        .optimize = optimize,

        .core = true,
    });

    for ([_]struct { name: []const u8 }{
        .{ .name = "simple-triangle" },
        .{ .name = "simple-triangle-msaa" },
        .{ .name = "simple-circle" },
        .{ .name = "simple-circle-msaa" },
        .{ .name = "0-draw-geometry" },
        .{ .name = "1-draw-grid" },
        .{ .name = "2-colorful-grid" },
        .{ .name = "3-manage-cell-state" },
        .{ .name = "4-game-of-life" },
        .{ .name = "sdf-2d-circle" },
    }) |example| {
        const app = try mach.CoreApp.init(b, mach_dep.builder, .{
            .name = "mach-from-scratch",
            .src = b.fmt("src/{s}/main.zig", .{example.name}),
            .target = target,
            .optimize = optimize,
            .deps = &[_]std.Build.Module.Import{},
        });

        if (b.args) |args| app.run.addArgs(args);
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = b.path(b.fmt("src/{s}/main.zig", .{example.name})),
            .target = target,
            .optimize = optimize,
        });

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(b.fmt("run-{s}", .{example.name}), b.fmt("Run {s}", .{example.name}));
        run_step.dependOn(&app.run.step);
    }
}
