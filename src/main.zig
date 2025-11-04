const std = @import("std");
const w4 = @import("wasm4.zig");
const lola = @import("lola");

var global_buffer: [0x3f_10]u8 = undefined;
var buf_alloc: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;

// var diag: lola.compiler.Diagnostics = undefined;
var pool: lola.runtime.objects.ObjectPool([_]type{}) = undefined;
// var compile_unit: lola.CompileUnit = undefined;
var env: lola.runtime.Environment = undefined;
var vm: lola.runtime.vm.VM = undefined;
fn compile() !void {
    const main_lola = "main.lola.lm";
    const src = @embedFile(main_lola);

    var reader = std.Io.Reader.fixed(src);
    const compile_unit = try lola.CompileUnit.loadFromStream(alloc, &reader);
    defer compile_unit.deinit();

    pool = @TypeOf(pool).init(alloc);

    env = try lola.runtime.Environment.init(alloc, &compile_unit, pool.interface());

    vm = try lola.runtime.vm.VM.init(alloc, &env);
}

export fn start() void {
    running = true;
    buf_alloc = std.heap.FixedBufferAllocator.init(&global_buffer);
    alloc = buf_alloc.allocator();
    w4.trace("bello\n");
    compile() catch |e| {
        w4.trace(@errorName(e));
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
// fn run() !void {
//     const limit = 100;

//     const result = vm.execute(limit) catch |err| {
//         if (@errorReturnTrace()) |err_trace| {
//             const tree: *std.builtin.StackTrace = err_trace;
//             tree.format(&output) catch unreachable;
//         } else {
//             output.print("Panic during execution: {s}\n", .{@errorName(err)}) catch unreachable;
//         }
//         w4.trace("Call stack:\n");

//         vm.printStackTrace(&output) catch {
//             w4.trace("can't print stack trace\n");
//         };
//         return error.VMError;
//     };

//     pool.clearUsageCounters();

//     try pool.walkEnvironment(env);
//     try pool.walkVM(vm);

//     pool.collectGarbage();

//     switch (result) {
//         .completed => {
//             running = false;
//             return error.Completed;
//         },
//         .exhausted => {},
//         .paused => {},
//     }
// }
export fn update() void {
    if (running) {
        // run() catch |err| {
        //     output.print("error: {s}\n", .{@errorName(err)}) catch unreachable;
        //     running = false;
        // };
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
