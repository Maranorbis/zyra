const std = @import("std");
const testing = std.testing;

const Flag = struct {
    long: []const u8,
    short: []const u8,
    value: type,
};

const Positional = struct {
    pos: comptime_int,
    value: type,
};

const ArgumentKind = enum { flag, positional };
pub const Argument = union(ArgumentKind) {
    flag: Flag,
    positional: Positional,

    // Namespace, spearating instantiated fields from initialization methods.
    pub const Factory = struct {
        pub fn flag(comptime long: []const u8, comptime short: []const u8) Argument {
            return .{ .flag = Flag{ .long = long, .short = short, .value = bool } };
        }

        pub fn valueFlag(comptime T: type, comptime long: []const u8, comptime short: []const u8) Argument {
            return .{ .flag = Flag{ .long = long, .short = short, .value = T } };
        }

        pub fn positional(comptime T: type, comptime pos: comptime_int) Argument {
            return .{ .positional = Positional{ .pos = pos, .value = T } };
        }
    };
};

test "Flag" {
    const testFlag = Flag{ .long = "test", .short = "t", .value = bool };

    try testing.expectEqualStrings("test", testFlag.long);
    try testing.expectEqualStrings("t", testFlag.short);

    try testing.expectEqual(bool, testFlag.value);
    try testing.expectEqualStrings(@typeName(bool), @typeName(testFlag.value));
}

test "Positional" {
    const positionalArg = Positional{ .pos = 0, .value = []const u8 };

    try testing.expectEqual(0, positionalArg.pos);
    try testing.expectEqual([]const u8, positionalArg.value);
    try testing.expectEqualStrings(@typeName([]const u8), @typeName(positionalArg.value));
}

test "Argument" {
    const standardArg = Argument.Factory.flag("test", "t");
    const boolFlagArg = Argument.Factory.valueFlag(bool, "test", "t");
    const stringFlagArg = Argument.Factory.valueFlag([]const u8, "value", "v");

    const pos1Arg = Argument.Factory.positional(usize, 1);
    const pos2Arg = Argument.Factory.positional([]const u8, 2);

    try testing.expectEqualStrings("test", standardArg.flag.long);
    try testing.expectEqualStrings("t", standardArg.flag.short);
    try testing.expectEqual(bool, standardArg.flag.value);
    try testing.expectEqualStrings(@typeName(bool), @typeName(standardArg.flag.value));

    try testing.expectEqualStrings(standardArg.flag.long, boolFlagArg.flag.long);
    try testing.expectEqualStrings(standardArg.flag.short, boolFlagArg.flag.short);
    try testing.expectEqual(standardArg.flag.value, boolFlagArg.flag.value);
    try testing.expectEqualStrings(@typeName(standardArg.flag.value), @typeName(boolFlagArg.flag.value));

    try testing.expectEqualStrings("value", stringFlagArg.flag.long);
    try testing.expectEqualStrings("v", stringFlagArg.flag.short);
    try testing.expectEqual([]const u8, stringFlagArg.flag.value);
    try testing.expectEqualStrings(@typeName([]const u8), @typeName(stringFlagArg.flag.value));

    try testing.expectEqual(1, pos1Arg.positional.pos);
    try testing.expectEqual(usize, pos1Arg.positional.value);
    try testing.expectEqualStrings(@typeName(usize), @typeName(pos1Arg.positional.value));

    try testing.expectEqual(2, pos2Arg.positional.pos);
    try testing.expectEqual([]const u8, pos2Arg.positional.value);
    try testing.expectEqualStrings(@typeName([]const u8), @typeName(pos2Arg.positional.value));

    try testing.expectEqual(stringFlagArg.flag.value, pos2Arg.positional.value);
    try testing.expectEqualStrings(@typeName(stringFlagArg.flag.value), @typeName(pos2Arg.positional.value));
}
