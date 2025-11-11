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

const SALLOC_SIZE: usize = (30 * 1024) - @sizeOf(PoolType) - @sizeOf(@TypeOf(env)) - @sizeOf(@TypeOf(vm)) - @sizeOf(@TypeOf(compile_unit));
var global_buffer: [SALLOC_SIZE]u8 = undefined;
const VALLOC = std.mem.ValidationAllocator(SALLOC);
const SALLOC = salloc.SAlloc; //16KB
var salloc_alloc: SALLOC = undefined;
// var valloc_alloc: VALLOC = undefined;
var alloc: std.mem.Allocator = undefined;

// var diag: lola.compiler.Diagnostics = undefined;
pub const PoolType = lola.runtime.objects.ObjectPool([_]type{
    libs.w4.Gamepad,
} ++ if (opts.runtime) .{
    libs.runtime.LoLaDictionary,
    libs.runtime.LoLaList,
} else .{} ++ if (opts.byte_array) .{
    libs.byte_array.ByteArray,
} else .{});
var pool: PoolType = undefined;
var compile_unit: lola.CompileUnit = undefined;
var env: lola.runtime.Environment = undefined;
var vm: lola.runtime.vm.VM = undefined;
fn compile() !void {
    const main_lola = "main.lola.lm";
    const src = @embedFile(main_lola);

    var reader = std.Io.Reader.fixed(src);
    compile_unit = try lola.CompileUnit.loadFromStream(alloc, &reader);

    pool = PoolType.init(alloc);

    env = try lola.runtime.Environment.init(alloc, &compile_unit, pool.interface());
    try env.installFunction("Print", .initSimpleUser(api.print));
    try env.installFunction("Wait", .{ .asyncUser = .{
        .call = api.Wait,
        .context = lola.runtime.Context.null_pointer,
        .destructor = null,
    } });

    if (opts.array)
        try env.installModule(libs.array, lola.runtime.Context.null_pointer);
    if (opts.math)
        try env.installModule(libs.math, lola.runtime.Context.null_pointer);
    if (opts.string)
        try env.installModule(libs.string, lola.runtime.Context.null_pointer);
    if (opts.runtime)
        try env.installModule(libs.runtime, lola.runtime.Context.null_pointer);
    if (opts.stdlib)
        try env.installModule(libs.stdlib, lola.runtime.Context.null_pointer);
    if (opts.byte_array)
        try env.installModule(libs.byte_array, lola.runtime.Context.null_pointer);

    try env.installModule(libs.w4, lola.runtime.Context.null_pointer);

    vm = try lola.runtime.vm.VM.init(alloc, &env);
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
    running = true;
    // logging_alloc = @TypeOf(logging_alloc).init(&output);
    // alloc = logging_alloc.get();

    // valloc_alloc.underlying_allocator.init(&global_buffer);
    salloc_alloc.init(&global_buffer);
    alloc = salloc_alloc.allocator();

    compile() catch |err| {
        output.print("compile error: {s}\n", .{@errorName(err)}) catch unreachable;
        output.flush() catch unreachable;
        running = false;
    };
}
var running: bool = undefined;
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
var trace_buffer: [1024]u8 = undefined;
var output = trace_writer(&trace_buffer);
var first: bool = false;
fn run() !void {
    if (!first) {
        output.print("bytes free {}\n", .{salloc_alloc.count_free()}) catch unreachable;
        first = true;
    }
    // const limit = 100;

    const result = vm.execute(null) catch |err| {
        output.print("Panic during execution: {s}\n", .{@errorName(err)}) catch unreachable;
        output.print("Call stack:\n", .{}) catch unreachable;

        vm.printStackTrace(&output) catch {
            w4.trace("can't print stack trace\n");
        };
        return error.VMError;
    };

    pool.clearUsageCounters();

    try pool.walkEnvironment(env);
    try pool.walkVM(vm);

    pool.collectGarbage();

    switch (result) {
        .completed => {
            return error.Completed;
        },
        .exhausted => unreachable,
        .paused => {},
    }
}
export fn update() void {
    if (running) {
        run() catch |err| {
            output.print("error: {s}\n", .{@errorName(err)}) catch unreachable;
            running = false;
            output.flush() catch unreachable;
        };
        // w4.trace("frame\n");
    } else {
        w4.DRAW_COLORS.* = 2;
        w4.text("Program has ended", 0, 0);
    }
    // w4.DRAW_COLORS.* = 2;
    // w4.text("Hello from Zig!", 10, 10);

    // const gamepad = w4.GAMEPAD1.*;
    // if (gamepad & w4.BUTTON_1 != 0) {
    //     w4.DRAW_COLORS.* = 4;
    // }

    // w4.blit(&smiley, 76, 76, 8, 8, w4.BLIT_1BPP);
    // w4.text("Press X to blink", 16, 90);
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
    // Ignore all non-error logging from sources other than
    // .my_project, .nice_library and the default
    const scope_prefix = "(" ++ switch (scope) {
        .my_project, .nice_library, std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
            @tagName(scope)
        else
            return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    nosuspend output.print(prefix ++ format ++ "\n", args) catch return;
}

//api
const api = struct {
    const Environment = lola.runtime.Environment;
    const Context = lola.runtime.Context;
    const Value = lola.runtime.value.Value;
    // lola.runtime.Environment.UserFunctionCall
    fn print(
        environment: *Environment,
        context: Context,
        args: []const Value,
    ) anyerror!Value {
        _ = environment;
        _ = context;
        for (args) |value| {
            switch (value) {
                .string => |str| output.writeAll(str.contents) catch unreachable,
                else => try output.print("{f}", .{value}),
            }
        }
        output.flush() catch unreachable;
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
