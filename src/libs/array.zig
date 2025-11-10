const std = @import("std");
const lola = @import("lola");

pub fn Array(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;

    const length = try args[0].toInteger(usize);
    const init_val = if (args.len > 1) args[1] else .void;

    const arr = try lola.runtime.value.Array.init(env.allocator, length);
    for (arr.contents) |*item| {
        item.* = try init_val.clone();
    }
    return lola.runtime.value.Value.fromArray(arr);
}

pub fn Range(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;

    if (args.len == 2) {
        const start = try args[0].toInteger(usize);
        const length = try args[1].toInteger(usize);

        const arr = try lola.runtime.value.Array.init(env.allocator, length);
        for (arr.contents, 0..) |*item, i| {
            item.* = lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(start + i)));
        }
        return lola.runtime.value.Value.fromArray(arr);
    } else {
        const length = try args[0].toInteger(usize);
        const arr = try lola.runtime.value.Array.init(env.allocator, length);
        for (arr.contents, 0..) |*item, i| {
            item.* = lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(i)));
        }
        return lola.runtime.value.Value.fromArray(arr);
    }
}

pub fn Slice(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 3)
        return error.InvalidArgs;

    const array = try args[0].toArray();
    const start = try args[1].toInteger(usize);
    const length = try args[2].toInteger(usize);

    // Out of bounds
    if (start >= array.contents.len)
        return lola.runtime.value.Value.fromArray(try lola.runtime.value.Array.init(env.allocator, 0));

    const actual_length = @min(length, array.contents.len - start);

    var arr = try lola.runtime.value.Array.init(env.allocator, actual_length);
    errdefer arr.deinit();

    for (arr.contents, 0..) |*item, i| {
        item.* = try array.contents[start + i].clone();
    }

    return lola.runtime.value.Value.fromArray(arr);
}

pub fn IndexOf(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 2)
        return error.InvalidArgs;
    if (args[0] == .string) {
        if (args[1] != .string)
            return error.TypeMismatch;
        const haystack = args[0].string.contents;
        const needle = args[1].string.contents;

        return if (std.mem.indexOf(u8, haystack, needle)) |index|
            lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(index)))
        else
            .void;
    } else if (args[0] == .array) {
        const haystack = args[0].array.contents;
        for (haystack, 0..) |val, i| {
            if (val.eql(args[1]))
                return lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(i)));
        }
        return .void;
    } else {
        return error.TypeMismatch;
    }
}

pub fn LastIndexOf(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 2)
        return error.InvalidArgs;
    if (args[0] == .string) {
        if (args[1] != .string)
            return error.TypeMismatch;
        const haystack = args[0].string.contents;
        const needle = args[1].string.contents;

        return if (std.mem.lastIndexOf(u8, haystack, needle)) |index|
            lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(index)))
        else
            .void;
    } else if (args[0] == .array) {
        const haystack = args[0].array.contents;

        var i: usize = haystack.len;
        while (i > 0) {
            i -= 1;
            if (haystack[i].eql(args[1]))
                return lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(i)));
        }
        return .void;
    } else {
        return error.TypeMismatch;
    }
}
