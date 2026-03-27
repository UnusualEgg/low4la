const std = @import("std");
const w4 = @import("wasm4");
const lola = @import("lola");
const salloc = @import("salloc");
const opts = @import("build_opts");

pub const libs = struct {
    const array = @import("libs/array.zig");
    const math = @import("libs/math.zig");
    const stdlib = @import("libs/stdlib.zig");
    const runtime = @import("libs/runtime.zig");
    const string = @import("libs/string.zig");
    const w4 = @import("libs/w4.zig");
    const byte_array = @import("libs/byte_array.zig");
};

const State = struct {
    salloc_alloc: SALLOC = undefined,
    alloc: std.mem.Allocator = undefined,
    pool: PoolType = undefined,
    compile_unit: lola.CompileUnit = undefined,
    env: lola.runtime.Environment = undefined,
    vm: lola.runtime.VM = undefined,

    running: bool = undefined,
    trace_buffer: [1024]u8 = undefined,
    output: std.Io.Writer = undefined,
    first: bool = false,
};
var state: State = .{};
// const VALLOC = std.mem.ValidationAllocator(SALLOC);
const SALLOC = salloc.SAlloc;
// var valloc_alloc: VALLOC = undefined;

pub const PoolType = lola.runtime.objects.ObjectPool([_]type{
    libs.w4.Gamepad,
} ++ if (opts.runtime) .{
    libs.runtime.LoLaDictionary,
    libs.runtime.LoLaList,
} else .{} ++ if (opts.byte_array) .{
    libs.byte_array.ByteArray,
} else .{});

fn compile() !void {
    const main_lola = "main.lola.lm";
    const src = @embedFile(main_lola);

    var reader = std.Io.Reader.fixed(src);
    state.compile_unit = try lola.CompileUnit.loadFromStream(state.alloc, &reader);

    state.pool = PoolType.init(state.alloc);

    state.env = try lola.runtime.Environment.init(state.alloc, &state.compile_unit, state.pool.interface());
    try state.env.installModule(api, .null_pointer);

    if (opts.array)
        try state.env.installModule(libs.array, lola.runtime.Context.null_pointer);
    if (opts.math)
        try state.env.installModule(libs.math, lola.runtime.Context.null_pointer);
    if (opts.string)
        try state.env.installModule(libs.string, lola.runtime.Context.null_pointer);
    if (opts.runtime)
        try state.env.installModule(libs.runtime, lola.runtime.Context.null_pointer);
    if (opts.stdlib)
        try state.env.installModule(libs.stdlib, lola.runtime.Context.null_pointer);
    if (opts.byte_array)
        try state.env.installModule(libs.byte_array, lola.runtime.Context.null_pointer);

    try state.env.installModule(libs.w4, lola.runtime.Context.null_pointer);

    state.vm = try lola.runtime.vm.VM.init(state.alloc, &state.env);
}
fn LoggingAlloc(inner_alloc: std.mem.Allocator) type {
    return struct {
        const Self = @This();
        const Alignment = std.mem.Alignment;
        inner_alloc: std.mem.Allocator,
        stream: *std.Io.Writer,
        // stream: *std.Io.Writer,
        fn vtable_alloc(ptr: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.stream.print("alloc {} bytes", .{len}) catch unreachable;
            self.stream.flush() catch unreachable;
            return self.inner_alloc.rawAlloc(len, alignment, ret_addr);
        }
        fn resize(ptr: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.stream.print("resize {} to {}", .{ memory.len, new_len }) catch unreachable;
            self.stream.flush() catch unreachable;
            return self.inner_alloc.rawResize(memory, alignment, new_len, ret_addr);
        }
        fn remap(ptr: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.stream.print("remap {} to {}", .{ memory.len, new_len }) catch unreachable;
            self.stream.flush() catch unreachable;
            return self.inner_alloc.rawRemap(memory, alignment, new_len, ret_addr);
        }
        fn free(ptr: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.stream.print("free {} bytes", .{memory.len}) catch unreachable;
            self.stream.flush() catch unreachable;
            self.inner_alloc.rawFree(memory, alignment, ret_addr);
        }
        pub fn get(self: *Self) std.mem.Allocator {
            return std.mem.Allocator{ .ptr = self, .vtable = &.{
                .alloc = vtable_alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            } };
        }
        pub fn init(stream: *std.Io.Writer) Self {
            return Self{ .inner_alloc = inner_alloc, .stream = stream };
        }
    };
}
export fn start() void {
    state.output = trace_writer(&state.trace_buffer);

    state.running = true;

    state.salloc_alloc.initWithFreeMem(State, &state);
    state.alloc = state.salloc_alloc.allocator();

    compile() catch |err| {
        state.output.print("compile error: {s}\n", .{@errorName(err)}) catch unreachable;
        state.output.flush() catch unreachable;
        state.running = false;
    };
}
fn drain_trace(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    if (w.end > 0) {
        w4.trace(w.buffered());
        w.end = 0;
    }
    var written: usize = 0;
    for (data[0 .. data.len - 1]) |buf| {
        w4.trace(buf);
        written += data.len;
    }
    const last = data[data.len - 1];
    for (0..splat) |_| {
        w4.trace(last);
        written += last.len;
    }
    return written;
}
fn trace_writer(buffer: []u8) std.Io.Writer {
    return std.Io.Writer{
        .vtable = &std.Io.Writer.VTable{
            .drain = drain_trace,
        },
        .buffer = buffer,
    };
}

fn run() !void {
    if (!state.first) {
        state.output.print("bytes free {}\n", .{state.salloc_alloc.count_free()}) catch unreachable;
        state.first = true;
    }
    // const limit = 100;

    const result = state.vm.execute(null) catch |err| {
        state.output.print("Panic during execution: {s}\n", .{@errorName(err)}) catch unreachable;
        state.output.print("Call stack:\n", .{}) catch unreachable;

        state.vm.printStackTrace(&state.output) catch {
            w4.trace("can't print stack trace\n");
        };
        return error.VMError;
    };

    state.pool.clearUsageCounters();

    try state.pool.walkEnvironment(state.env);
    try state.pool.walkVM(state.vm);

    state.pool.collectGarbage();

    switch (result) {
        .completed => {
            return error.Completed;
        },
        .exhausted => unreachable,
        .paused => {},
    }
}
export fn update() void {
    if (state.running) {
        run() catch |err| {
            state.output.print("error: {s}\n", .{@errorName(err)}) catch unreachable;
            state.running = false;
            state.output.print("bytes free: {}\n", .{state.salloc_alloc.count_free()}) catch unreachable;
            if (@errorReturnTrace()) |trace| {
                state.output.print("{f}\n", .{trace}) catch unreachable;
            }
            state.output.flush() catch unreachable;
        };
    } else {
        w4.DRAW_COLORS.* = 2;
        w4.text("Program has ended", 0, 0);
    }
}

//logging
pub const std_options: std.Options = .{
    // Set the log level to info
    .log_level = .info,

    // Define logFn to override the std implementation
    .logFn = myLogFn,
};
pub fn myLogFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    // Print the message, silently ignoring any errors
    nosuspend state.output.print(prefix ++ format ++ "\n", args) catch return;
}

//api
const api = struct {
    const Environment = lola.runtime.Environment;
    const Context = lola.runtime.Context;
    const Value = lola.runtime.value.Value;
    pub fn Print(
        environment: *Environment,
        context: Context,
        args: []const Value,
    ) anyerror!Value {
        _ = environment;
        _ = context;
        for (args) |value| {
            switch (value) {
                .string => |str| state.output.writeAll(str.contents) catch unreachable,
                else => try state.output.print("{f}", .{value}),
            }
        }
        state.output.flush() catch unreachable;
        return .void;
    }
    pub fn Wait(_: *lola.runtime.Environment, call_context: lola.runtime.Context, args: []const lola.runtime.value.Value) anyerror!lola.runtime.AsyncFunctionCall {
        _ = call_context;

        if (args.len != 0)
            return error.InvalidArgs;

        return lola.runtime.AsyncFunctionCall{
            .context = lola.runtime.Context.null_pointer,
            .destructor = null,
            .execute = struct {
                fn execute(_: lola.runtime.Context) anyerror!?lola.runtime.value.Value {
                    return .void;
                }
            }.execute,
        };
    }
};
