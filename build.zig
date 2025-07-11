const std = @import("std");

const ProfileMode = enum {
    enabled,
    time_only,
    disabled,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});


    const profiler = b.addModule("profiler", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const profile_mode = b.option(ProfileMode, "profile_mode", "Whether and how to enable profiling") orelse ProfileMode.disabled;
    const options = b.addOptions();
    options.addOption(ProfileMode, "profile_mode", profile_mode);

    profiler.addOptions("profiler_config", options);

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
