const std = @import("std");
const lola = @import("lola");

const whitespace = [_]u8{
    0x09, // horizontal tab
    0x0A, // line feed
    0x0B, // vertical tab
    0x0C, // form feed
    0x0D, // carriage return
    0x20, // space
};

pub fn Length(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return switch (args[0]) {
        .string => |str| lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(str.contents.len))),
        .array => |arr| lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(arr.contents.len))),
        else => error.TypeMismatch,
    };
}

pub fn SubString(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len < 2 or args.len > 3)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    if (args[1] != .number)
        return error.TypeMismatch;
    if (args.len == 3 and args[2] != .number)
        return error.TypeMismatch;

    const str = args[0].string;
    const start = try args[1].toInteger(usize);
    if (start >= str.contents.len)
        return lola.runtime.value.Value.initString(env.allocator, "");

    const sliced = if (args.len == 3)
        str.contents[start..][0..@min(str.contents.len - start, try args[2].toInteger(usize))]
    else
        str.contents[start..];

    return try lola.runtime.value.Value.initString(env.allocator, sliced);
}
pub fn Trim(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const str = args[0].string;

    return try lola.runtime.value.Value.initString(
        env.allocator,
        std.mem.trim(u8, str.contents, &whitespace),
    );
}

pub fn TrimLeft(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const str = args[0].string;

    return try lola.runtime.value.Value.initString(
        env.allocator,
        std.mem.trimLeft(u8, str.contents, &whitespace),
    );
}

pub fn TrimRight(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const str = args[0].string;

    return try lola.runtime.value.Value.initString(
        env.allocator,
        std.mem.trimRight(u8, str.contents, &whitespace),
    );
}

pub fn Byte(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const value = args[0].string.contents;
    if (value.len > 0)
        return lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(value[0])))
    else
        return .void;
}

pub fn Chr(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    const val = try args[0].toInteger(u8);

    return try lola.runtime.value.Value.initString(
        env.allocator,
        &[_]u8{val},
    );
}

pub fn NumToString(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;
    var buffer: [256]u8 = undefined;
    var stream = std.Io.Writer.fixed(&buffer);

    const slice = if (args.len == 2) blk: {
        const base = try args[1].toInteger(u8);

        const val = try args[0].toInteger(isize);
        try stream.printInt(val, base, .upper, .{});
        break :blk stream.buffered();
    } else blk: {
        const val = try args[0].toNumber();

        try stream.print("{d}", .{val});
        break :blk stream.buffered();
    };
    return try lola.runtime.value.Value.initString(env.allocator, slice);
}

pub fn StringToNum(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;
    const str = try args[0].toString();

    if (args.len == 2) {
        const base = try args[1].toInteger(u8);

        const text = if (base == 16) blk: {
            var tmp = str;
            if (std.mem.startsWith(u8, tmp, "0x"))
                tmp = tmp[2..];
            if (std.mem.endsWith(u8, tmp, "h"))
                tmp = tmp[0 .. tmp.len - 1];
            break :blk tmp;
        } else str;

        const val = try std.fmt.parseInt(isize, text, base); // return .void;

        return lola.runtime.value.Value.initNumber(@as(f64, @floatFromInt(val)));
    } else {
        const val = std.fmt.parseFloat(f64, str) catch return .void;
        return lola.runtime.value.Value.initNumber(val);
    }
}

pub fn Split(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len < 2 or args.len > 3)
        return error.InvalidArgs;

    const input = try args[0].toString();
    const separator = try args[1].toString();
    const removeEmpty = if (args.len == 3) try args[2].toBoolean() else false;

    var items = std.ArrayList(lola.runtime.value.Value).empty;
    defer {
        for (items.items) |*i| {
            i.deinit();
        }
        items.deinit(env.allocator);
    }

    var iter = std.mem.splitAny(u8, input, separator);
    while (iter.next()) |slice| {
        if (!removeEmpty or slice.len > 0) {
            var val = try lola.runtime.value.Value.initString(env.allocator, slice);
            errdefer val.deinit();

            try items.append(env.allocator, val);
        }
    }

    return lola.runtime.value.Value.fromArray(lola.runtime.value.Array{
        .allocator = env.allocator,
        .contents = try items.toOwnedSlice(env.allocator),
    });
}

pub fn Join(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;

    const array = try args[0].toArray();
    const separator: []const u8 = if (args.len == 2) try args[1].toString() else "";

    for (array.contents) |item| {
        if (item != .string)
            return error.TypeMismatch;
    }

    var result = std.ArrayList(u8).empty;
    defer result.deinit(env.allocator);

    for (array.contents, 0..) |item, i| {
        if (i > 0) {
            try result.appendSlice(env.allocator, separator);
        }
        try result.appendSlice(env.allocator, try item.toString());
    }

    return lola.runtime.value.Value.fromString(lola.runtime.value.String.initFromOwned(
        env.allocator,
        try result.toOwnedSlice(env.allocator),
    ));
}
