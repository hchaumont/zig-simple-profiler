const std = @import("std");
const timer = @import("timer.zig");

const Anchor = struct {
    tsc_inclusive: u64,
    tsc_exclusive: u64,
    hit_count: u32,
};

pub const ZoneTag = enum {
    functionA,
    functionB,

    fn getSize() usize {
        return @typeInfo(ZoneTag).@"enum".fields.len;
    }
};

const Profiler = struct {
    anchors: [ZoneTag.getSize()]Anchor,
    start_tsc: u64,
    end_tsc: u64,
    current_parent_index: ?usize,

    pub fn startTiming(self: *Profiler) void {
        self.start_tsc = timer.rdtsc();
    }

    pub fn stopTiming(self: *Profiler) void {
        self.end_tsc = timer.rdtsc();
    }

    pub fn printResults(self: *Profiler) !void {
        const stdout = std.io.getStdOut().writer();
        const total_cycles: u64 = self.end_tsc -% self.start_tsc;
        try stdout.print("\nTotal cycles: {d}", .{total_cycles});
        for (self.anchors, 0..) |a, i| {
            const anchor_tag: ZoneTag = @enumFromInt(i);
            const exclusive_pct: f64 = @as(f64, @floatFromInt(a.tsc_exclusive)) / @as(f64, @floatFromInt(total_cycles)) * 100;
            try stdout.print("\n  {s} ({d} hits): {d:.2}%, {d} cycles", .{@tagName(anchor_tag), a.hit_count, exclusive_pct, a.tsc_exclusive});
            if (a.tsc_inclusive != a.tsc_exclusive) {
                const inclusive_pct = @as(f64, @floatFromInt(a.tsc_inclusive)) / @as(f64, @floatFromInt(total_cycles)) * 100;
                try stdout.print(" ({d:.2}% including children)", .{inclusive_pct});
            }
        }
    }

    pub fn tag(self: *Profiler, comptime zone_tag: ZoneTag) Block {
        _ = self;
        const anchor_index = @intFromEnum(zone_tag);
        return Block.init(anchor_index);
    }
};

pub var GlobalProfiler = Profiler{
    .anchors = .{Anchor{
        .tsc_inclusive = 0,
        .tsc_exclusive = 0,
        .hit_count = 0,
    }} ** ZoneTag.getSize(),
    .start_tsc = undefined,
    .end_tsc = undefined,
    .current_parent_index = null,
};

const Block = struct {
    prev_tsc_inclusive: u64,
    start_tsc: u64,
    anchor_index: usize,
    parent_anchor_index: ?usize,

    pub fn init(anchor_index: usize) Block {
        const anchor: *Anchor = &GlobalProfiler.anchors[anchor_index];
        const prev_tsc_inclusive = anchor.tsc_inclusive;
        const parent_anchor_index: ?usize = GlobalProfiler.current_parent_index;
        const current_tsc = timer.rdtsc();

        GlobalProfiler.current_parent_index = anchor_index;

        return Block{
            .prev_tsc_inclusive = prev_tsc_inclusive,
            .start_tsc = current_tsc,
            .anchor_index = anchor_index,
            .parent_anchor_index = parent_anchor_index,
        };
    }

    pub fn deinit(self: *Block) void {
        GlobalProfiler.current_parent_index = self.parent_anchor_index;
        const total = timer.rdtsc() -% self.start_tsc;
        var anchor = &GlobalProfiler.anchors[self.anchor_index];
        anchor.hit_count += 1;
        anchor.tsc_inclusive = self.prev_tsc_inclusive +% total;
        anchor.tsc_exclusive +%= total;
        if (self.parent_anchor_index) |i| {
            var parent_anchor = &GlobalProfiler.anchors[i];
            parent_anchor.tsc_exclusive -%= total;
        }
    }
};
