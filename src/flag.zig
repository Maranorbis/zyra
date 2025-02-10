const std = @import("std");

const testing = std.testing;

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap([]const u8);

pub const Error = error{
    FlagAlreadyExists,
    FlagDoesNotExist,
    ValueTypeNotSupported,
    ValueParseFailed,
} || std.mem.Allocator.Error;

pub const Flag = struct {
    long: [:0]const u8,
    short: [:0]const u8,
};

pub const FlagValueMap = struct {
    allocator: Allocator,
    _internal: StringHashMap,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            ._internal = StringHashMap.init(allocator),
        };
    }

    pub fn has(self: *Self, key: []const u8) bool {
        return self._internal.contains(key);
    }

    pub fn get(self: *Self, key: []const u8) Error![]const u8 {
        if (!self.has(key)) return Error.FlagDoesNotExist;

        return self._internal.get(key).?;
    }

    pub fn getValueAs(self: *Self, comptime T: type, key: []const u8) Error!T {
        return switch (T) {
            usize => std.fmt.parseInt(usize, try self.get(key), 10) catch {
                return Error.ValueParseFailed;
            },
            bool => {
                const val = try self.get(key);

                if (std.mem.eql(u8, val, "1")) {
                    return true;
                } else if (std.mem.eql(u8, val, "0")) {
                    return false;
                }

                if (std.ascii.eqlIgnoreCase(val, "true")) {
                    return true;
                } else if (std.ascii.eqlIgnoreCase(val, "false")) {
                    return false;
                }

                return Error.ValueParseFailed;
            },
            []const u8 => try self.get(key),
            else => Error.ValueTypeNotSupported,
        };
    }

    pub fn put(self: *Self, key: []const u8, value: []const u8) Error!void {
        if (self.has(key)) return Error.FlagAlreadyExists;

        return try self._internal.put(key, value);
    }

    pub fn count(self: *Self) u32 {
        return self._internal.count();
    }

    pub fn deinit(self: *Self) void {
        self._internal.deinit();
    }
};

pub fn stripPrefix(value: []const u8) []const u8 {
    return std.mem.trimLeft(u8, value, "-");
}

pub fn stripSpace(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " ");
}

pub fn sanitize(value: []const u8) []const u8 {
    return stripPrefix(stripSpace(value));
}

test "Flag initializes" {
    const flag: Flag = .{
        .long = "test",
        .short = "t",
    };

    try testing.expectEqualSentinel(u8, 0, "test", flag.long);
    try testing.expectEqualSentinel(u8, 0, "t", flag.short);
}
