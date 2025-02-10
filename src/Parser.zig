const Parser = @This();

const std = @import("std");
const flag = @import("flag.zig");

const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;
const process = std.process;
const testing = std.testing;

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

const Flag = flag.Flag;
const FlagMap = std.StaticStringMap(Flag);

const FlagValueMap = flag.FlagValueMap;
const PositionalArray = std.ArrayList([:0]const u8);

pub const ParseError = error{
    InvalidArgSequence,
    FlagNotFound,
    AlreadyExists,
} || flag.Error;

allocator: Allocator,
message: []const u8 = "",

// This heiarchy must be respected, one cannot be present before the other.
const ParseMode = enum {
    command,
    flag,
    positional,
};

const ParseResult = struct {
    allocator: Allocator,
    flags: FlagValueMap,
    positionals: PositionalArray,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .flags = FlagValueMap.init(allocator),
            .positionals = PositionalArray.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.flags.deinit();
        self.positionals.deinit();
    }
};

pub fn init(allocator: Allocator) Parser {
    return .{
        .allocator = allocator,
    };
}

pub fn parse(self: *Parser, args: []const [:0]const u8, flagMap: FlagMap) ParseError!ParseResult {
    var mode: ParseMode = .flag;
    var res = ParseResult.init(self.allocator);

    for (args[1..]) |arg| {
        switch (parseMode(arg)) {
            .command => {
                if (mode == .flag or mode == .positional) {
                    self.message = "A command was provided in-between flags and positional parameters.\n";
                    res.deinit();
                    return ParseError.InvalidArgSequence;
                }

                // TODO: Set command in ParseResult
            },
            .flag => {
                if (mode == .command) mode = .flag;

                const key, const value = blk: {
                    const kv = flag.sanitize(arg);
                    if (kv.len == 0) break :blk .{ "", "" };

                    const idx = std.mem.indexOfScalar(u8, kv, '=');
                    if (idx) |i| {
                        break :blk .{ kv[0..i], kv[(i + 1)..] };
                    } else {
                        break :blk .{ kv, "" };
                    }
                };

                const defined_flag: Flag = flagMap.get(key) orelse {
                    res.deinit();
                    return ParseError.FlagNotFound;
                };

                // TODO: Handle error properly and release the resources otherwise memory leak will occurr
                try res.flags.put(defined_flag.long, value);
                try res.flags.put(defined_flag.short, value);
            },
            .positional => {
                if (mode == .flag or mode == .command) mode = .positional;

                try res.positionals.append(arg);
            },
        }
    }

    return res;
}

// TODO: Add check for Command
fn parseMode(arg: []const u8) ParseMode {
    if (std.mem.eql(u8, "--", arg[0..2]) or std.mem.eql(u8, "-", arg[0..1])) {
        return ParseMode.flag;
    }

    return ParseMode.positional;
}

test "initializes" {
    const parser = Parser.init(std.testing.allocator);
    try testing.expectEqual(parser.allocator.ptr, std.testing.allocator.ptr);
}

test "parse returns ParseResult" {
    var parser = Parser.init(std.testing.allocator);

    const args = [_][:0]const u8{ "app", "arg1", "arg2", "--value=20", "-b=40" };

    const flagMap = FlagMap.initComptime(&.{
        .{ "value", Flag{ .long = "value", .short = "v" } },
        .{ "v", Flag{ .long = "value", .short = "v" } },

        .{ "bust", Flag{ .long = "bust", .short = "b" } },
        .{ "b", Flag{ .long = "bust", .short = "b" } },
    });

    var result = try parser.parse(&args, flagMap);
    defer result.deinit();

    try testing.expectEqual(result.flags.count(), flagMap.kvs.len);
    try testing.expectEqual(result.positionals.items.len, 2);

    const expected_positonal_arr = [_][]const u8{ "arg1", "arg2" };

    try testing.expectEqualSlices([]const u8, result.positionals.items, &expected_positonal_arr);

    try testing.expectEqualStrings("20", try result.flags.get("v"));
    try testing.expectEqual(20, try result.flags.getValueAs(usize, "v"));
    try testing.expectEqualStrings(@typeName(usize), @typeName(@TypeOf(try result.flags.getValueAs(usize, "v"))));
}

test "parse returns FlagNotFound error on invalid flag" {
    var parser = Parser.init(std.testing.allocator);

    const args = [_][:0]const u8{ "app", "arg1", "arg2", "--flag", "arg3", "-g", "--value=20", "-b=40", "--", "-l=" };

    const flagMap = FlagMap.initComptime(&.{
        .{ "value", Flag{ .long = "value", .short = "v" } },
        .{ "v", Flag{ .long = "value", .short = "v" } },

        .{ "bust", Flag{ .long = "value", .short = "v" } },
        .{ "b", Flag{ .long = "value", .short = "v" } },
    });

    try testing.expectError(ParseError.FlagNotFound, parser.parse(&args, flagMap));
}
