const std = @import("std");
const profiler = @import("profiler");

const Zones = enum {
    main,
    functionA,
    functionB,
};

const Profiler = profiler.ProfilerInstance(Zones);

pub fn main() !void {
    Profiler.startTiming();
    var block = Profiler.tag(Zones.main);
    defer block.deinit();
    for (0..7) |i| {
        functionA(i);
    }
    Profiler.stopTiming();
    try Profiler.printResults(true);
}

fn functionA(sleep_ms: u64) void {
    var block = Profiler.tag(Zones.functionA);
    defer block.deinit();
    std.debug.print("functionA\n", .{});
    std.Thread.sleep(std.time.ns_per_ms * sleep_ms);
    if (sleep_ms % 2 == 0) {
        functionB(sleep_ms);
    }
}

fn functionB(sleep_ms: u64) void {
    var block = Profiler.tag(Zones.functionB);
    defer block.deinit();
    std.debug.print("functionB\n", .{});
    std.Thread.sleep(std.time.ns_per_ms * sleep_ms);
    if (sleep_ms > 0 and sleep_ms % 3 == 0) {
        functionA(sleep_ms / 6);
    }
}
