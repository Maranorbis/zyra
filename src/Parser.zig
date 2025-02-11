const Parser = @This();

const std = @import("std");
const flag = @import("flag.zig");

const Command = @import("Command.zig");
const ParseResult = @import("ParseResult.zig");

const Allocator = std.mem.Allocator;
const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;
const process = std.process;
const testing = std.testing;

const Flag = flag.Flag;
const FlagMap = std.StaticStringMap(Flag);
const CommandMap = std.StaticStringMap(Command);

const ParseError = error{
    InvalidArgSequence,
    FlagNotFound,
    CommandNotFound,
    AlreadyExists,
} || flag.Error;

allocator: Allocator,
message: []const u8 = "",

pub fn init(allocator: Allocator) Parser {
    return .{
        .allocator = allocator,
    };
}

pub fn parse(self: *Parser, args: []const [:0]const u8, flagMap: FlagMap) ParseError!ParseResult {
    var res = ParseResult.init(self.allocator);

    for (args) |arg| {
        const isFlag = std.mem.eql(u8, "--", arg[0..2]) or std.mem.eql(u8, "-", arg[0..1]);

        switch (isFlag) {
            true => {
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
            false => {
                try res.positionals.append(arg);
            },
        }
    }

    return res;
}

test "initializes" {
    const parser = Parser.init(std.testing.allocator);
    try testing.expectEqual(parser.allocator.ptr, std.testing.allocator.ptr);
}

test "parse returns ParseResult" {
    var parser = Parser.init(std.testing.allocator);

    // First paramter is assumed to be skipped here, which is binary or application itself.
    const args = [_][:0]const u8{ "arg1", "arg2", "--value=20", "-b=40" };

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

    // First paramter is assumed to be skipped here, which is binary or application itself.
    const args = [_][:0]const u8{ "arg1", "arg2", "--flag", "arg3", "-g", "--value=20", "-b=40", "--", "-l=" };

    const flagMap = FlagMap.initComptime(&.{
        .{ "value", Flag{ .long = "value", .short = "v" } },
        .{ "v", Flag{ .long = "value", .short = "v" } },

        .{ "bust", Flag{ .long = "value", .short = "v" } },
        .{ "b", Flag{ .long = "value", .short = "v" } },
    });

    try testing.expectError(ParseError.FlagNotFound, parser.parse(&args, flagMap));
}
