const std = @import("std");
const lola = @import("lola");

pub fn DeltaEqual(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 3)
        return error.InvalidArgs;
    const a = try args[0].toNumber();
    const b = try args[1].toNumber();
    const delta = try args[2].toNumber();
    return lola.runtime.value.Value.initBoolean(@abs(a - b) < delta);
}

pub fn Floor(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(@floor(try args[0].toNumber()));
}

pub fn Ceiling(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(@ceil(try args[0].toNumber()));
}

pub fn Round(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(@round(try args[0].toNumber()));
}

pub fn Sin(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(@sin(try args[0].toNumber()));
}

pub fn Cos(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(@cos(try args[0].toNumber()));
}

pub fn Tan(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(@tan(try args[0].toNumber()));
}

pub fn Atan(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len == 1) {
        return lola.runtime.value.Value.initNumber(
            std.math.atan(try args[0].toNumber()),
        );
    } else if (args.len == 2) {
        return lola.runtime.value.Value.initNumber(std.math.atan2(
            try args[0].toNumber(),
            try args[1].toNumber(),
        ));
    } else {
        return error.InvalidArgs;
    }
}

pub fn Sqrt(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(std.math.sqrt(try args[0].toNumber()));
}

pub fn Pow(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 2)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(std.math.pow(
        f64,
        try args[0].toNumber(),
        try args[1].toNumber(),
    ));
}

pub fn Log(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len == 1) {
        return lola.runtime.value.Value.initNumber(
            std.math.log10(try args[0].toNumber()),
        );
    } else if (args.len == 2) {
        return lola.runtime.value.Value.initNumber(std.math.log(
            f64,
            try args[1].toNumber(),
            try args[0].toNumber(),
        ));
    } else {
        return error.InvalidArgs;
    }
}

pub fn Exp(env: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) !lola.runtime.value.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lola.runtime.value.Value.initNumber(@exp(try args[0].toNumber()));
}
