const std = @import("std");
const testing = std.testing;

pub const Command = struct {
    name: [:0]const u8,
    desc: [:0]const u8 = "",
    args: []const Argument = &.{},
    sub_cmds: []const Command = &.{},
};

pub const Flag = struct {
    long: [:0]const u8,
    short: [:0]const u8,
    desc: [:0]const u8 = "",
    required: bool = false,
};

pub const ValueFlag = struct {
    long: [:0]const u8,
    short: [:0]const u8,
    desc: [:0]const u8 = "",
    value: type,
    required: bool = false,
};

pub const Positional = struct {
    pos: usize,
    value: type,
    required: bool = false,
};

pub const ArgumentKind = enum { flag, value_flag, positional };

pub const Argument = union(ArgumentKind) {
    const Self = @This();

    flag: Flag,
    value_flag: ValueFlag,
    positional: Positional,

    pub const Type = struct {
        pub fn flag(comptime Option: Flag) Self {
            return .{ .flag = Option };
        }

        pub fn value_flag(comptime Option: ValueFlag) Self {
            return .{ .value_flag = Option };
        }

        pub fn positional(comptime Option: Positional) Self {
            return .{ .positional = Option };
        }
    };

    pub fn kind(self: *const Self) ArgumentKind {
        return switch (self.*) {
            .flag => .flag,
            .value_flag => .value_flag,
            .positional => .positional,
        };
    }
};

test "Positional" {
    const pos_str = Positional{ .pos = 0, .value = []const u8 };
    const pos_usize = Positional{ .pos = 1, .value = usize, .required = true };

    try testing.expectEqual(0, pos_str.pos);
    try testing.expectEqual(false, pos_str.required);
    try testing.expectEqual([]const u8, pos_str.value);
    try testing.expectEqualStrings(@typeName([]const u8), @typeName(pos_str.value));

    try testing.expect(pos_usize.required);
    try testing.expectEqual(1, pos_usize.pos);
    try testing.expectEqual(usize, pos_usize.value);
    try testing.expectEqualStrings(@typeName(usize), @typeName(pos_usize.value));
}

test "Flag" {
    const long = "test";
    const short = "t";
    const desc = "testing flag";
    const required = true;

    const testFlag = Flag{ .long = long, .short = short };
    const testRequiredFlag = Flag{ .long = long, .short = short, .desc = desc, .required = required };

    try testing.expectEqualStrings(long, testFlag.long);
    try testing.expectEqualStrings(short, testFlag.short);
    try testing.expectEqualStrings("", testFlag.desc);
    try testing.expectEqual(false, testFlag.required);

    try testing.expectEqualStrings(long, testRequiredFlag.long);
    try testing.expectEqualStrings(short, testRequiredFlag.short);
    try testing.expectEqualStrings(desc, testRequiredFlag.desc);
    try testing.expect(testRequiredFlag.required);
}

test "ValueFlag" {
    const long = "test";
    const short = "t";
    const desc = "testing flag";
    const required = true;

    const testFlag = ValueFlag{ .long = long, .short = short, .value = bool };
    const testRequiredFlag = ValueFlag{ .long = long, .short = short, .desc = desc, .required = required, .value = []const u8 };

    try testing.expectEqualStrings(long, testFlag.long);
    try testing.expectEqualStrings(short, testFlag.short);
    try testing.expectEqualStrings("", testFlag.desc);
    try testing.expectEqual(false, testFlag.required);
    try testing.expectEqual(bool, testFlag.value);
    try testing.expectEqualStrings(@typeName(bool), @typeName(testFlag.value));

    try testing.expectEqualStrings(long, testRequiredFlag.long);
    try testing.expectEqualStrings(short, testRequiredFlag.short);
    try testing.expectEqualStrings(desc, testRequiredFlag.desc);
    try testing.expect(testRequiredFlag.required);
    try testing.expectEqual([]const u8, testRequiredFlag.value);
    try testing.expectEqualStrings(@typeName([]const u8), @typeName(testRequiredFlag.value));
}

test "Argument" {
    const long = "test";
    const short = "t";
    const desc = "testing flag";

    // Flags
    const std_flag_arg = Argument.Type.flag(.{ .long = long, .short = short });
    try testing.expectEqualStrings(long, std_flag_arg.flag.long);
    try testing.expectEqualStrings(short, std_flag_arg.flag.short);
    try testing.expectEqual(false, std_flag_arg.flag.required);

    const bool_flag_arg = Argument.Type.value_flag(.{ .long = long, .short = short, .value = bool });
    try testing.expectEqualStrings(long, bool_flag_arg.value_flag.long);
    try testing.expectEqualStrings(short, bool_flag_arg.value_flag.short);
    try testing.expectEqual(false, bool_flag_arg.value_flag.required);
    try testing.expectEqual(bool, bool_flag_arg.value_flag.value);

    const str_flag_arg = Argument.Type.value_flag(.{ .long = long, .short = short, .desc = desc, .required = true, .value = []const u8 });
    try testing.expectEqualStrings(long, str_flag_arg.value_flag.long);
    try testing.expectEqualStrings(short, str_flag_arg.value_flag.short);
    try testing.expectEqual([]const u8, str_flag_arg.value_flag.value);
    try testing.expect(str_flag_arg.value_flag.required);

    // Positionals
    const pos_usize_arg = Argument.Type.positional(.{ .pos = 1, .value = usize });
    try testing.expectEqual(1, pos_usize_arg.positional.pos);
    try testing.expectEqual(usize, pos_usize_arg.positional.value);

    const pos_str_arg = Argument.Type.positional(.{ .pos = 2, .value = []const u8, .required = true });
    try testing.expect(pos_str_arg.positional.required);
    try testing.expectEqual(2, pos_str_arg.positional.pos);
    try testing.expectEqual([]const u8, pos_str_arg.positional.value);
}

test "Command" {
    const long = "test";
    const short = "t";

    const name = "test";
    const cmd_desc = "example test command";

    const args =
        &.{
        Argument.Type.flag(.{ .long = long, .short = short }),
        Argument.Type.value_flag(.{ .long = long, .short = short, .value = bool }),
        Argument.Type.positional(.{ .pos = 2, .value = []const u8, .required = true }),
    };

    const cmd = Command{ .name = name };
    try testing.expectEqualStrings(name, cmd.name);
    try testing.expectEqualStrings("", cmd.desc);
    try testing.expectEqual(0, cmd.args.len);
    try testing.expectEqualSlices(Argument, &.{}, cmd.args);

    const cmd1 = Command{ .name = name, .args = args };
    try testing.expectEqualStrings(name, cmd1.name);
    try testing.expectEqualStrings("", cmd1.desc);
    try testing.expectEqual(3, cmd1.args.len);
    try testing.expectEqualSlices(Argument, args, cmd1.args);

    const cmd2 = Command{ .name = name, .desc = cmd_desc, .args = args };
    try testing.expectEqualStrings(name, cmd2.name);
    try testing.expectEqualStrings(cmd_desc, cmd2.desc);
    try testing.expectEqual(3, cmd2.args.len);
    try testing.expectEqualSlices(Argument, args, cmd2.args);
}
