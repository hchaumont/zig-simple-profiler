const std = @import("std");
const builtin = @import("builtin");

const Anchor = struct {
    tsc_inclusive: u64,
    tsc_exclusive: u64,
    hit_count: u32,
};

fn Profiler(comptime ZonesEnum: type) type {
    return struct {
        anchors: [@typeInfo(ZonesEnum).@"enum".fields.len]Anchor,
        start_tsc: u64,
        end_tsc: u64,
        current_parent_index: ?usize,

        const Self = @This();

        pub fn startTiming(self: *Self) void {
            self.start_tsc = timer.readCounter();
        }

        pub fn stopTiming(self: *Self) void {
            self.end_tsc = timer.readCounter();
        }

        pub fn printResults(self: *Self, print_time: bool) !void {
            const stdout = std.io.getStdOut().writer();
            const total_cycles: u64 = self.end_tsc -% self.start_tsc;
            try stdout.print("\nTotal cycles: {d}", .{total_cycles});
            for (self.anchors, 0..) |a, i| {
                const anchor_tag: ZonesEnum = @enumFromInt(i);
                const exclusive_pct: f64 = @as(f64, @floatFromInt(a.tsc_exclusive)) / @as(f64, @floatFromInt(total_cycles)) * 100;
                try stdout.print("\n  {s} ({d} hits): {d:.2}%, {d} cycles", .{ @tagName(anchor_tag), a.hit_count, exclusive_pct, a.tsc_exclusive });
                if (a.tsc_inclusive != a.tsc_exclusive) {
                    const inclusive_pct = @as(f64, @floatFromInt(a.tsc_inclusive)) / @as(f64, @floatFromInt(total_cycles)) * 100;
                    try stdout.print(" ({d:.2}% including children)", .{inclusive_pct});
                }
            }
            if (print_time) {
                const freq = timer.getCounterFrequency();
                try stdout.print("\n(Estimated) Counter frequency: {d} Hz", .{freq});
                const time = @as(f64, @floatFromInt(total_cycles)) / @as(f64, @floatFromInt(freq));
                try stdout.print("\n(Approximate) Total time: {d:.5} seconds", .{time});
            }
        }

        pub fn tag(self: *Self, comptime zone_tag: ZonesEnum) Block(ZonesEnum) {
            _ = self;
            const anchor_index = @intFromEnum(zone_tag);
            return Block(ZonesEnum).init(anchor_index);
        }
    };
}

pub fn ProfilerInstance(comptime ZonesEnum: type) *Profiler(ZonesEnum) {
    const static = struct {
        var instance: Profiler(ZonesEnum) = .{
            .anchors = .{Anchor{
                .tsc_inclusive = 0,
                .tsc_exclusive = 0,
                .hit_count = 0,
            }} ** @typeInfo(ZonesEnum).@"enum".fields.len,
            .start_tsc = undefined,
            .end_tsc = undefined,
            .current_parent_index = null,
        };
    };
    return &static.instance;
}

fn Block(comptime ZonesEnum: type) type {
    return struct {
        prev_tsc_inclusive: u64,
        start_tsc: u64,
        anchor_index: usize,
        parent_anchor_index: ?usize,

        const Self = @This();

        pub fn init(anchor_index: usize) Self {
            const anchor: *Anchor = &ProfilerInstance(ZonesEnum).anchors[anchor_index];
            const prev_tsc_inclusive = anchor.tsc_inclusive;
            const parent_anchor_index: ?usize = ProfilerInstance(ZonesEnum).current_parent_index;
            const current_tsc = timer.readCounter();

            ProfilerInstance(ZonesEnum).current_parent_index = anchor_index;

            return Self{
                .prev_tsc_inclusive = prev_tsc_inclusive,
                .start_tsc = current_tsc,
                .anchor_index = anchor_index,
                .parent_anchor_index = parent_anchor_index,
            };
        }

        pub fn deinit(self: *Self) void {
            ProfilerInstance(ZonesEnum).current_parent_index = self.parent_anchor_index;
            const total = timer.readCounter() -% self.start_tsc;
            var anchor = &ProfilerInstance(ZonesEnum).anchors[self.anchor_index];
            anchor.hit_count += 1;
            anchor.tsc_inclusive = self.prev_tsc_inclusive +% total;
            anchor.tsc_exclusive +%= total;
            if (self.parent_anchor_index) |i| {
                var parent_anchor = &ProfilerInstance(ZonesEnum).anchors[i];
                parent_anchor.tsc_exclusive -%= total;
            }
        }
    };
}

const timer = struct {
    inline fn readCounter() u64 {
        switch (builtin.cpu.arch) {
            .x86_64 => {
                // Refer to https://www.felixcloutier.com/x86/rdtsc
                var hi: u32 = 0;
                var low: u32 = 0;

                asm (
                    \\rdtsc
                    : [low] "={eax}" (low),
                      [hi] "={edx}" (hi),
                );
                return (@as(u64, hi) << 32) | @as(u64, low);
            },
            .aarch64 => {
                // Refer to https://arm.jonpalmisc.com/latest_sysreg/AArch64-cntvct_el0
                var counter: u64 = 0;
                asm volatile ("mrs %[counter], cntvct_el0"
                    : [counter] "=r" (counter),
                );
                return counter;
            },
            else => {
                @compileError("Unsupported architecture for high-resolution timing.");
            },
        }
    }

    fn getCounterFrequency() u64 {
        switch (builtin.cpu.arch) {
            .x86_64 => {
                // x86_x4 doesn't provide a way to read the counter frequency,
                // so we estimate it by seeing how many ticks occur in 100ms
                // according to the OS timer, and scaling
                return estimatex86CpuCounterFrequency(100);
            },
            .aarch64 => {
                // Refer to https://arm.jonpalmisc.com/latest_sysreg/AArch64-cntfrq_el0
                var freq: u64 = 0;
                asm volatile ("mrs %[freq], cntfrq_el0"
                    : [freq] "=r" (freq),
                );
                return freq;
            },
            else => {
                @compileError("Unsupported architecture for high-resolution timing.");
            },
        }
    }

    /// Given a positive number of ms, estimates the frequency of the CPU time
    /// stamp counter in Hz by comparing against the OS timer. Unlike with ARM,
    /// there isn't a convenient way to access the counter frequency.
    fn estimatex86CpuCounterFrequency(ms_to_wait: i64) u64 {
        const us_to_wait: i64 = ms_to_wait * std.time.us_per_ms;

        const cpu_tsc_start = readCounter();
        const os_timestamp_start = std.time.microTimestamp();

        var os_time_elapsed: i64 = 0;
        while (os_time_elapsed < us_to_wait) {
            os_time_elapsed = std.time.microTimestamp() - os_timestamp_start;
        }
        const cpu_tsc_end = readCounter();

        const cpu_ticks_elapsed = cpu_tsc_end - cpu_tsc_start;
        std.debug.assert(os_time_elapsed > 0);
        const os_time_unsigned: u64 = @intCast(os_time_elapsed);
        const cpu_timestamp_frequency = cpu_ticks_elapsed * std.time.us_per_s / os_time_unsigned;
        return cpu_timestamp_frequency;
    }
};

test "estimates x86 CPU timer frequency" {
    const ms_to_wait = 100;
    const freq = timer.estimatex86CpuCounterFrequency(ms_to_wait);
    try std.testing.expect(freq > 0);
}

test "reads time stamp counter" {
    const ts1 = timer.readCounter();
    const ts2 = timer.readCounter();
    try std.testing.expect(ts2 != ts1);
}
