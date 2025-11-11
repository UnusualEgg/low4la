const std = @import("std");
const lola = @import("lola");
const GlobalObjectPool = @import("../main.zig").PoolType;
const Environment = lola.runtime.Environment;
const Context = lola.runtime.Context;
const Value = lola.runtime.value.Value;

// CreateByteArray(len:usize,[init:u8]) ByteArray
pub fn CreateByteArray(environment: *Environment, context: lola.runtime.Context, args: []const Value) anyerror!Value {
    _ = context;
    if (args.len > 2 or args.len < 1)
        return error.InvalidArgs;

    const len = try args[0].toInteger(usize);
    const init = if (args.len > 1) try args[1].toInteger(u8) else 0;

    const list = try environment.allocator.create(ByteArray);
    errdefer environment.allocator.destroy(list);

    list.* = ByteArray{
        .allocator = environment.allocator,
        .data = try std.ArrayList(u8).initCapacity(environment.allocator, len),
    };
    list.data.appendNTimesAssumeCapacity(init, len);

    return Value.initObject(
        try environment.objectPool.castTo(GlobalObjectPool).createObject(list),
    );
}

pub const ByteArray = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    data: std.ArrayList(u8),
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
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn serializeObject(writer: lola.runtime.objects.OutputStream.Writer, object: *Self) !void {
        try writer.writeInt(u32, @as(u32, @intCast(object.data.items.len)), .little);
        for (object.data.items) |item| {
            try writer.writeByte(item);
        }
    }

    pub fn deserializeObject(allocator: std.mem.Allocator, reader: lola.runtime.objects.InputStream.Reader) !*Self {
        const item_count = try reader.takeInt(u32, .little);
        var list = try allocator.create(Self);
        list.* = Self{
            .allocator = allocator,
            .data = try std.ArrayList(u8).initCapacity(allocator, item_count),
        };
        errdefer list.destroyObject(); // this will also free memory!

        for (0..item_count) |_| {
            list.data.appendAssumeCapacity(try reader.takeByte());
        }

        return list;
    }

    const funcs = struct {
        pub fn Add(environment: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) anyerror!lola.runtime.value.Value {
            _ = environment;
            const list: *Self = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            try list.data.append(list.allocator, try args[0].toInteger(u8));

            return .void;
        }
        pub fn GetCount(environment: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) anyerror!lola.runtime.value.Value {
            _ = environment;
            const list: *Self = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;
            return lola.runtime.value.Value.initInteger(usize, list.data.items.len);
        }
        pub fn Get(environment: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) anyerror!lola.runtime.value.Value {
            _ = environment;
            const list: *Self = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;
            const index = try args[0].toInteger(usize);
            if (index >= list.data.items.len)
                return error.OutOfRange;

            return Value.initInteger(u8, list.data.items[index]);
        }

        pub fn Set(environment: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) anyerror!lola.runtime.value.Value {
            _ = environment;
            const list: *Self = context.cast(*Self);
            if (args.len != 2)
                return error.InvalidArgs;
            const index = try args[0].toInteger(usize);
            if (index >= list.data.items.len)
                return error.OutOfRange;

            list.data.items[index] = try args[1].toInteger(u8);

            return .void;
        }

        pub fn ToArray(environment: *const lola.runtime.Environment, context: lola.runtime.Context, args: []const lola.runtime.value.Value) anyerror!lola.runtime.value.Value {
            _ = environment;
            const list: *Self = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;

            var array = try lola.runtime.value.Array.init(list.allocator, list.data.items.len);
            errdefer array.deinit();

            for (array.contents, 0..) |*item, index| {
                item.* = Value.initInteger(u8, list.data.items[index]);
            }

            return lola.runtime.value.Value.fromArray(array);
        }
    };
};
