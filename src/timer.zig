const std = @import("std");
const testing = std.testing;

// Refer to https://www.felixcloutier.com/x86/rdtsc
pub inline fn rdtsc() u64 {
    var hi: u32 = 0;
    var low: u32 = 0;

    asm (
        \\rdtsc
        : [low] "={eax}" (low),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, low);
}

test "reads time stamp counter" {
    const ts1 = rdtsc();
    const ts2 = rdtsc();
    try std.testing.expect(ts2 != ts1);
}
