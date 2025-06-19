const std = @import("std");
const profiler = @import("profiler.zig");

pub fn main() !void {
    profiler.GlobalProfiler.startTiming();
    for (0..7) |i| {
        functionA(i);
    }
    profiler.GlobalProfiler.stopTiming();
    try profiler.GlobalProfiler.printResults();
}

fn functionA(sleep_ms: u64) void {
    var block = profiler.GlobalProfiler.tag(profiler.ZoneTag.functionA);
    defer block.deinit();
    std.debug.print("functionA\n", .{});
    std.Thread.sleep(std.time.ns_per_ms * sleep_ms);
    if (sleep_ms % 2 == 0) {
        functionB(sleep_ms);
    }
}

fn functionB(sleep_ms: u64) void {
    var block = profiler.GlobalProfiler.tag(profiler.ZoneTag.functionB);
    defer block.deinit();
    std.debug.print("functionB\n", .{});
    std.Thread.sleep(std.time.ns_per_ms * sleep_ms);
    if (sleep_ms > 0 and sleep_ms % 3 == 0) {
        functionA(sleep_ms / 6);
    }
}
