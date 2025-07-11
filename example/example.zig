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

    functionA(false);

    // simulate 50 ms of work
    std.Thread.sleep(std.time.ns_per_ms * 50);

    functionA(true);

    block.deinit();
    Profiler.stopTiming();
    try Profiler.printResults(true);
}

fn functionA(call_B: bool) void {
    var block = Profiler.tag(Zones.functionA);
    defer block.deinit();

    std.debug.print("functionA\n", .{});
    // simulate 200ms worth of work
    std.Thread.sleep(std.time.ns_per_ms * 200);

    if (call_B) {
        functionB(true);
    }
}

fn functionB(call_A: bool) void {
    var block = Profiler.tag(Zones.functionB);
    defer block.deinit();

    std.debug.print("functionB\n", .{});
    // simulate 100 ms of work
    std.Thread.sleep(std.time.ns_per_ms * 100);

    if (call_A) {
        functionA(false);
    }
}
