const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const profiler = b.addModule("profiler", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const example = b.addExecutable(.{
        .name = "example",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("example/example.zig"),
    });
    example.root_module.addImport("profiler", profiler);

    const run_exe = b.addRunArtifact(example);
    const run_step = b.step("example", "Run the example code");
    run_step.dependOn(&run_exe.step);
}
