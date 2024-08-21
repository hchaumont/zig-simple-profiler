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

// Given a positive number of ms, estimates the frequency of the CPU time stamp
// counter in Hz by comparing against the OS timer.
export fn estimateCpuTimerFrequency(ms_to_wait: i64) u64 {
    const us_to_wait: i64 = ms_to_wait * std.time.us_per_ms;

    const cpu_tsc_start = rdtsc();
    const os_timestamp_start = std.time.microTimestamp();

    var os_time_elapsed: i64 = 0;
    while (os_time_elapsed < us_to_wait) {
        os_time_elapsed = std.time.microTimestamp() - os_timestamp_start;
    }
    const cpu_tsc_end = rdtsc();

    const cpu_ticks_elapsed = cpu_tsc_end - cpu_tsc_start;
    std.debug.assert(os_time_elapsed > 0);
    const os_time_unsigned: u64 = @intCast(os_time_elapsed);
    const cpu_timestamp_frequency = cpu_ticks_elapsed * std.time.us_per_s / os_time_unsigned;
    return cpu_timestamp_frequency;
}

test "estimates CPU timer frequency" {
    const ms_to_wait = 100;
    const freq = estimateCpuTimerFrequency(ms_to_wait);
    try std.testing.expect(freq > 0);
}
