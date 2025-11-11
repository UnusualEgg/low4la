const std = @import("std");
const lola = @import("lola");

pub fn TypeOf(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initString(env.allocator, switch (args[0]) {
        .void => "void",
        .boolean => "boolean",
        .string => "string",
        .number => "number",
        .object => "object",
        .array => "array",
        .enumerator => "enumerator",
    });
}

pub fn ToString(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;

    if (args.len != 1)
        return error.InvalidArgs;

    const str = try std.fmt.allocPrint(env.allocator, "{f}", .{args[0]});

    return lola.runtime.value.Value.fromString(lola.runtime.value.String.initFromOwned(env.allocator, str));
}

pub fn HasFunction(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    switch (args.len) {
        1 => {
            const name = try args[0].toString();
            return lola.runtime.value.Value.initBoolean(env.functions.get(name) != null);
        },
        2 => {
            const obj = try args[0].toObject();
            const name = try args[1].toString();

            const maybe_method = try env.objectPool.getMethod(obj, name);

            return lola.runtime.value.Value.initBoolean(maybe_method != null);
        },
        else => return error.InvalidArgs,
    }
}

pub fn Serialize(env: *lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;

    const value = args[0];

    var string_buffer = std.Io.Writer.Allocating.init(env.allocator);
    defer string_buffer.deinit();

    try value.serialize(&string_buffer.writer);

    return lola.runtime.value.Value.fromString(lola.runtime.value.String.initFromOwned(env.allocator, try string_buffer.toOwnedSlice()));
}

pub fn Deserialize(env: *lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;

    const serialized_string = try args[0].toString();

    var stream = std.io.Reader.fixed(serialized_string);

    return try lola.runtime.value.Value.deserialize(&stream, env.allocator);
}
