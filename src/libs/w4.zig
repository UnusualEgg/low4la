const std = @import("std");
const w4 = @import("wasm4");
const lola = @import("lola");

const Environment = lola.runtime.Environment;
const Context = lola.runtime.Context;
const Value = lola.runtime.value.Value;
const GlobalObjectPool = @import("../main.zig").PoolType;

const GAMEPADS: *const [4]u8 = @ptrFromInt(0x16);
/// GetGamepad(gamepad_index:u2) Gamepad
/// there are 4 gamepads
pub fn GetGamepad(
    environment: *Environment,
    context: Context,
    args: []const Value,
) anyerror!Value {
    _ = context;
    if (args.len != 1) return error.InvalidArgs;
    const gamepad_num = try args[0].toInteger(u2);
    const gamepad_val = GAMEPADS[gamepad_num];
    const gamepad = try environment.allocator.create(Gamepad);
    gamepad.init(
        gamepad_num,
        gamepad_val,
        environment.allocator,
    );
    const object_pool: *GlobalObjectPool = environment.objectPool.castTo(GlobalObjectPool);
    return Value.initObject(try object_pool.createObject(gamepad));
}
pub const Gamepad = struct {
    const Self = @This();

    index: u2,
    contents: u8,
    allocator: std.mem.Allocator,

    pub fn init(self: *Self, index: u2, gamepad: u8, alloc: std.mem.Allocator) void {
        self.index = index;
        self.contents = gamepad;
        self.allocator = alloc;
    }

    pub fn getMethod(self: *Self, name: []const u8) ?lola.runtime.Function {
        inline for (comptime std.meta.declarations(funcs)) |decl| {
            if (std.mem.eql(u8, name, decl.name)) {
                return lola.runtime.Function{
                    .syncUser = .{
                        .context = lola.runtime.Context.make(*Self, self),
                        .call = @field(funcs, decl.name),
                        .destructor = null,
                    },
                };
            }
        }
        return null;
    }
    pub fn destroyObject(self: *Self) void {
        self.allocator.destroy(self);
    }
    pub fn serializeObject(writer: lola.runtime.objects.OutputStream.Writer, object: *Self) !void {
        try writer.writeByte(object.index);
        try writer.writeByte(object.contents);
    }
    pub fn deserializeObject(allocator: std.mem.Allocator, reader: lola.runtime.objects.InputStream.Reader) !*Self {
        const gamepad = try allocator.create(Self);
        gamepad.init(
            @truncate(try reader.takeByte()),
            try reader.takeByte(),
            allocator,
        );

        return gamepad;
    }

    const funcs = struct {
        pub fn Button1(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            return Value.initBoolean(gamepad.contents & w4.BUTTON_1 != 0);
        }
        pub fn Button2(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            return Value.initBoolean(gamepad.contents & w4.BUTTON_2 != 0);
        }
        pub fn ButtonUp(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            return Value.initBoolean(gamepad.contents & w4.BUTTON_UP != 0);
        }
        pub fn ButtonDown(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            return Value.initBoolean(gamepad.contents & w4.BUTTON_DOWN != 0);
        }
        pub fn ButtonLeft(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            return Value.initBoolean(gamepad.contents & w4.BUTTON_LEFT != 0);
        }
        pub fn ButtonRight(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            return Value.initBoolean(gamepad.contents & w4.BUTTON_RIGHT != 0);
        }
        pub fn Update(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            gamepad.contents = GAMEPADS[gamepad.index];
            return .void;
        }
        /// And(other:u8) Gamepad
        /// useful for checking if a button was held
        /// by calling this with the value of the buttons the previous frame
        pub fn And(environment: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 1) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            const other = try args[0].toInteger(u8);
            const new = try environment.allocator.create(Gamepad);
            new.init(
                gamepad.index,
                gamepad.contents & other,
                environment.allocator,
            );
            const object_pool: *GlobalObjectPool = environment.objectPool.castTo(GlobalObjectPool);
            return Value.initObject(try object_pool.createObject(new));
        }
        pub fn Number(_: *Environment, context: Context, args: []const Value) anyerror!Value {
            if (args.len != 0) return error.InvalidArgs;
            const gamepad: *Self = context.cast(*Self);
            return Value.initInteger(u8, gamepad.contents);
        }
    };
};
/// Poke1(addr:u16, value: u8) void
pub fn Poke1(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 2) return error.InvalidArgs;
    const T = u8;
    const ptr: *T = @ptrFromInt(try args[0].toInteger(u16));
    ptr.* = try args[1].toInteger(T);
    return .void;
}
/// Poke2(addr:u16, value: u16) void
pub fn Poke2(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 2) return error.InvalidArgs;
    const T = u16;
    const ptr: *T = @ptrFromInt(try args[0].toInteger(u16));
    ptr.* = try args[1].toInteger(T);
    return .void;
}
/// Poke4(addr:u16, value: u32) void
pub fn Poke4(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 2) return error.InvalidArgs;
    const T = u32;
    const ptr: *T = @ptrFromInt(try args[0].toInteger(u16));
    ptr.* = try args[1].toInteger(T);
    return .void;
}
/// Peek1(addr:u16) u8
pub fn Peek1(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArgs;
    const T = u8;
    const ptr: *T = @ptrFromInt(try args[0].toInteger(u16));
    return Value.initInteger(T, ptr.*);
}
/// Peek2(addr:u16) u16
pub fn Peek2(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArgs;
    const T = u16;
    const ptr: *T = @ptrFromInt(try args[0].toInteger(u16));
    return Value.initInteger(T, ptr.*);
}
/// Peek4(addr:u16) u32
pub fn Peek4(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArgs;
    const T = u32;
    const ptr: *T = @ptrFromInt(try args[0].toInteger(u16));
    return Value.initInteger(T, ptr.*);
}
/// SetPalette(index: u2, value: u32) void
/// SetPalette(array: [4]u32) void
/// has to be at least 4 elements
pub fn SetPalette(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    switch (args.len) {
        1 => {
            const array = try args[0].toArray();
            if (array.contents.len > 4) return error.InvalidArgs;
            for (array.contents, 0..) |value, i| {
                w4.PALETTE[i] = try value.toInteger(u32);
            }
            return .void;
        },
        2 => {
            const index = try args[0].toInteger(u2);
            const value = try args[1].toInteger(u32);
            w4.PALETTE[index] = value;
            return .void;
        },
        else => return error.InvalidArgs,
    }
}
/// DrawColors(value:u16) void
pub fn DrawColors(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArgs;
    w4.DRAW_COLORS.* = try args[0].toInteger(u16);
    return .void;
}

// drawing functions

/// Blit(spr:string, x:i32, y:i32, width:u32, height:u32, 2bp: bool, [flip_x:bool, [flip_y:bool, [rotate: bool]]]) void
pub fn Blit(
    environment: *Environment,
    context: Context,
    args: []const Value,
) anyerror!Value {
    _ = environment;
    _ = context;
    if (args.len < 6 or args.len > 9) return error.InvalidArgs;
    const spr = try args[0].toString();
    const x = try args[1].toInteger(i32);
    const y = try args[2].toInteger(i32);
    const w = try args[3].toInteger(u32);
    const h = try args[4].toInteger(u32);
    const bpp = try args[5].toBoolean();
    const flip_x = if (args.len > 6) try args[6].toBoolean() else false;
    const flip_y = if (args.len > 7) try args[7].toBoolean() else false;
    const rotate = if (args.len > 8) try args[8].toBoolean() else false;

    const flags: u32 =
        (@intFromBool(bpp)) |
        (@intFromBool(flip_x) * w4.BLIT_FLIP_X) |
        (@intFromBool(flip_y) * w4.BLIT_FLIP_Y) |
        (@intFromBool(rotate) * w4.BLIT_ROTATE);
    w4.blit(spr.ptr, x, y, w, h, flags);
    return .void;
}
/// BlitSub(spr:string, x:i32, y:i32, width:u32, height:u32, 2bp: bool, src_x:u32, src_y:u32, stride:u32, [flip_x:bool, [flip_y:bool, [rotate: bool]]]) void
pub fn BlitSub(
    environment: *Environment,
    context: Context,
    args: []const Value,
) anyerror!Value {
    _ = environment;
    _ = context;
    if (args.len < 9 or args.len > 12) return error.InvalidArgs;
    const spr = try args[0].toString();
    const x = try args[1].toInteger(i32);
    const y = try args[2].toInteger(i32);
    const w = try args[3].toInteger(u32);
    const h = try args[4].toInteger(u32);
    const bpp = try args[5].toBoolean();
    const src_x = try args[6].toInteger(u32);
    const src_y = try args[7].toInteger(u32);
    const stride = try args[8].toInteger(u32);
    const flip_x = if (args.len > 9) try args[9].toBoolean() else false;
    const flip_y = if (args.len > 10) try args[10].toBoolean() else false;
    const rotate = if (args.len > 11) try args[11].toBoolean() else false;

    const flags: u32 =
        (@intFromBool(bpp)) |
        (@intFromBool(flip_x) * w4.BLIT_FLIP_X) |
        (@intFromBool(flip_y) * w4.BLIT_FLIP_Y) |
        (@intFromBool(rotate) * w4.BLIT_ROTATE);
    w4.blitSub(spr.ptr, x, y, w, h, src_x, src_y, stride, flags);
    return .void;
}

/// Line(x1: i32, y1: i32, x2: i32, y2: i32) void
pub fn Line(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 4) return error.InvalidArgs;
    const x1 = try args[0].toInteger(i32);
    const y1 = try args[1].toInteger(i32);
    const x2 = try args[2].toInteger(i32);
    const y2 = try args[3].toInteger(i32);
    w4.line(x1, y1, x2, y2);
    return .void;
}
/// HLine(x1: i32, y1: i32, len: u32) void
pub fn HLine(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 3) return error.InvalidArgs;
    const x1 = try args[0].toInteger(i32);
    const y1 = try args[1].toInteger(i32);
    const len = try args[2].toInteger(u32);
    w4.hline(x1, y1, len);
    return .void;
}
/// VLine(x1: i32, y1: i32, len: u32) void
pub fn VLine(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 3) return error.InvalidArgs;
    const x1 = try args[0].toInteger(i32);
    const y1 = try args[1].toInteger(i32);
    const len = try args[2].toInteger(u32);
    w4.hline(x1, y1, len);
    return .void;
}
/// Oval(x1: i32, y1: i32, width: u32, height: u32) void
pub fn Oval(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 4) return error.InvalidArgs;
    const x1 = try args[0].toInteger(i32);
    const y1 = try args[1].toInteger(i32);
    const w = try args[2].toInteger(u32);
    const h = try args[3].toInteger(u32);
    w4.oval(x1, y1, w, h);
    return .void;
}

/// Rect([x:i32, y:i32], width:u32, height:u32) void
pub fn Rect(
    environment: *Environment,
    context: Context,
    args: []const Value,
) anyerror!Value {
    _ = environment;
    _ = context;
    const x: i32, const y: i32, const w: u32, const h: u32 = blk: {
        switch (args.len) {
            2 => {
                break :blk .{
                    0,
                    0,
                    try args[0].toInteger(u32),
                    try args[1].toInteger(u32),
                };
            },
            4 => {
                break :blk .{
                    try args[0].toInteger(i32),
                    try args[1].toInteger(i32),
                    try args[2].toInteger(u32),
                    try args[3].toInteger(u32),
                };
            },
            else => {
                return error.InvalidArgs;
            },
        }
    };
    w4.rect(x, y, w, h);
    return .void;
}

/// Text(text:string) void
pub fn Text(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 3) return error.InvalidArgs;
    w4.text(try args[0].toString(), try args[1].toInteger(i32), try args[2].toInteger(i32));
    return .void;
}

//sound

/// Tone(frequency: u32, duration: u32, volume: u32, flags: u32) void
/// frequency in hurtz
/// duration in frames(1/60th of a second)
pub fn Tone(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 4) return error.InvalidArgs;
    const freq = try args[0].toInteger(u32);
    const duration = try args[1].toInteger(u32);
    const volume = try args[2].toInteger(u32);
    const flags = try args[3].toInteger(u32);

    w4.tone(freq, duration, volume, flags);
    return .void;
}
/// ToneEx(start_freq: u16, end_freq: u16, sustain: u8, release:u8, decay:u8, attack:u8, vol: u16, sustain_vol: u8, attack_vol: u8, [channel: u2, mode: u2, pan: u2, note_mode: bool]) void
pub fn ToneEx(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 9 and args.len != 13) return error.InvalidArgs;
    const start_freq = try args[0].toInteger(u16);
    const end_freq = try args[1].toInteger(u16);
    const sustain = try args[2].toInteger(u8);
    const release = try args[3].toInteger(u8);
    const decay = try args[4].toInteger(u8);
    const attack = try args[5].toInteger(u8);
    const vol = try args[6].toInteger(u16);
    const sustain_vol = try args[7].toInteger(u8);
    const attack_vol = try args[8].toInteger(u8);
    const channel, const mode, const pan, const note_mode = blk: {
        if (args.len == 13) {
            break :blk .{
                try args[8].toInteger(u2),
                try args[8].toInteger(u2),
                try args[8].toInteger(u2),
                try args[8].toBoolean(),
            };
        } else {
            break :blk .{ 0, 0, 0, false };
        }
    };
    const freq = @as(u32, start_freq) << 16 | end_freq;
    var duration: u32 = attack;
    duration <<= 8;
    duration |= decay;
    duration <<= 8;
    duration |= release;
    duration <<= 8;
    duration |= sustain;

    var volume: u32 = attack_vol;
    volume <<= 8;
    volume |= sustain_vol;
    volume <<= 16;
    volume |= vol;

    var flags: u32 = @intFromBool(note_mode);
    flags <<= 2;
    flags |= pan;
    flags <<= 2;
    flags |= mode;
    flags <<= 2;
    flags |= channel;

    w4.tone(freq, duration, volume, flags);
    return .void;
}

//storage

/// DiskW(buffer:string, size: u32) u32
pub fn DiskW(_: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 2) return error.InvalidArgs;
    const buffer = try args[0].toString();
    const size = try args[1].toInteger(u32);

    return Value.initInteger(u32, w4.diskw(buffer.ptr, size));
}
/// DiskR(size: u32) string
pub fn DiskR(env: *const Environment, _: Context, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArgs;
    const size = try args[0].toInteger(u32);

    const buffer = try env.allocator.alloc(u8, size);

    _ = w4.diskr(buffer.ptr, size);
    return Value.fromString(lola.runtime.value.String.initFromOwned(env.allocator, buffer));
}
