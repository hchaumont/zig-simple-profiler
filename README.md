# Simple Zig profiler
A simple instrumentation based profiler for Zig code, inspired by the C++
profiler
[here](https://github.com/cmuratori/computer_enhance/blob/main/perfaware/part2/listing_0091_switchable_profiler.cpp).
Uses hardware counters to time sections of code. On x86_64 processors, uses the
`rdtsc` instruction, and on aarch_64 processors reads the `CNTVCT_EL0`
register.

```
Total cycles: 18570574
  main                 (1 hits):  7.11%, 1320647 cycles (100.00% including children)
  functionA            (3 hits): 79.34%, 14733258 cycles (92.89% including children)
  functionB            (1 hits): 13.55%, 2516408 cycles (40.01% including children)
(Estimated) Counter frequency: 24000000 Hz
(Approximate) Total time: 0.77377 seconds
```

Supports correct attribution of nested and recursive function calls, but is not
designed for or suitable as-is for multi-threaded code.

## Usage

1. Use `zig fetch` to fetch the dependency:
```sh
zig fetch --save git+https://github.com/hchaumont/zig-simple-profiler.git
```
This will fetch the dependency to your zig cache and add it to your
dependencies in the `build.zig.zon` file, like so:
```
.dependencies = .{
    .simple_profiler = .{
        .url = "git+https://github.com/hchaumont/zig-simple-profiler.git#9e069e30081d9b68879d5e92d716b9a561412134",
        .hash = "simple_profiler-0.1.0-xx9lLhMzAABCJcoB8BagERP4KUfVWYZeX-RjV1CI9CY_",
    },
},
```

2. Include the dependency in your `build.zig` file:
```zig
const profiler_dependency = b.dependency("simple_profiler", .{
    .target = target,
    .optimize = optimize,
    .profile_mode = @as([]const u8, "enabled"),
});

const profiler_mod = profiler_dependency.module("profiler");

exe_mod.root_module.addImport("profiler", profiler_mod);
```

`profile_mode` can be one of the three following values:
- 'enabled' - This fully enables the profiler, reporting on all the marked
sections.
- 'time_only' - This only enables the top-level begin and end timing.
- 'disabled' - This fully disables the profiler.


3. In your code, import the profiler module and define the profiling zones you
   want to use:
```zig
const std = @import("std");
const profiler = @import("profiler");

const Zones = enum {
    main,
    functionA,
    functionB,
};

const Profiler = profiler.ProfilerInstance(Zones);
```

4. Mark your code zones of interest:

- Call `Profiler.startTiming()` to initialize data collection, and
`Profiler.stopTiming()` at the end of data collection.
- In between those two calls, to time a specific Zone, call `var block =
Profiler.tag(Zones.yourZoneName)`. It will return the block of tracking data
for that Zone. Call `block.deinit()` to finish the timing the Zone.
- Call `Profiler.printResults` to print the results report. If the
`print_time` parameter is `true`, it will use the time stamp counter
frequency to estimate the total time between the `startTiming` and `stopTiming`
calls. Note that for x86_64 processors, we can't necessarily get the time stamp
counter frequency, so the frequency will be estimated by comparing against
100ms of clock time.

```zig
pub fn main() !void {
    Profiler.startTiming();

    // Your code here

    Profiler.stopTiming();
    try Profiler.printResults(true);
}
```

You can Use `defer` for automatic cleanup in functions:
```zig
fn myFunction() void {
    var block = Profiler.tag(Zones.myFunction);
    defer block.deinit();

    // Your function code here
}
```

See `example/example.zig` for a simple working example using the profiler. To
run the example code:
```sh
zig build example --Dprofile_mode=enabled
```
To use the time-only mode: 
```sh
zig build example --Dprofile_mode=time_only
```
