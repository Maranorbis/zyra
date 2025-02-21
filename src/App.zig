const Self = @This();

const std = @import("std");
const argument = @import("argument.zig");

const Argument = argument.Argument;
const Command = argument.Command;
const Arguments = []const Argument;
const Commands = []const Command;

const testing = std.testing;

pub const Info = struct {
    name: [:0]const u8,
    desc: [:0]const u8 = "",
    version: [:0]const u8 = "0.0.0",
};

pub const Context = struct {
    args: []const Argument = &.{},
    cmds: []const Command = &.{},
};

info: Info,
context: Context,

pub fn init(comptime AppInfo: Info, comptime Ctx: Context) Self {
    // TOOD: Automatically add (--help, -h) and (--version, -v) options/flags if an empty `Context` is provided.
    //
    // According to GNU Standards for Command Line Interfaces:
    //
    // "All programs should support two standard options: ‘--version’ and ‘--help’."
    //
    // [Source](https://www.gnu.org/prep/standards/html_node/Command_002dLine-Interfaces.html)

    return .{
        .info = AppInfo,
        .context = Ctx,
    };
}

test "App Info" {
    const name = "test_app";
    const desc = "just for testing";
    const version = "0.1.0";

    const app = Self.init(.{ .name = name, .desc = desc, .version = version }, .{});

    try testing.expectEqualStrings(name, app.info.name);
    try testing.expectEqualStrings(desc, app.info.desc);
    try testing.expectEqualStrings(version, app.info.version);
    try testing.expectEqual(0, app.context.args.len);
    try testing.expectEqual(0, app.context.cmds.len);

    const bare_app = Self.init(.{ .name = name }, .{});

    try testing.expectEqualStrings(name, bare_app.info.name);
    try testing.expectEqualStrings("", bare_app.info.desc);
    try testing.expectEqualStrings("0.0.0", bare_app.info.version);
    try testing.expectEqual(0, bare_app.context.args.len);
    try testing.expectEqual(0, bare_app.context.cmds.len);
}

test "App Context" {
    const name = "test_app";
    const desc = "just for testing";
    const version = "0.1.0";

    const args = &.{
        Argument.Type.flag(.{ .long = "test", .short = "t", .desc = "test flag" }),
        Argument.Type.value_flag(.{ .long = "value", .short = "v", .desc = "value flag", .value = usize, .required = true }),
        Argument.Type.positional(.{ .pos = 0, .value = usize, .required = true }),
    };

    const cmds = &.{
        Command{
            .name = "run",
            .args = &.{
                Argument.Type.value_flag(.{ .long = "file", .short = "f", .value = []const u8, .required = true }),
                Argument.Type.flag(.{ .long = "verbose", .short = "v" }),
            },
            .sub_cmds = &.{
                Command{
                    .name = "debug",
                    .args = &.{
                        Argument.Type.value_flag(.{ .long = "level", .short = "l", .value = isize }),
                    },
                },
            },
        },
        Command{
            .name = "del",
            .args = &.{
                Argument.Type.flag(.{ .long = "force", .short = "f" }),
            },
            .sub_cmds = &.{
                Command{ .name = "perm" },
            },
        },
    };

    const app = Self.init(.{
        .name = name,
        .desc = desc,
        .version = version,
    }, .{
        .args = args,
        .cmds = cmds,
    });

    try testing.expectEqualStrings(name, app.info.name);
    try testing.expectEqualStrings(desc, app.info.desc);
    try testing.expectEqualStrings(version, app.info.version);

    // Count Commands
    var nested_cmd_count: usize = 0;
    var arg_count: usize = 0;
    var nested_arg_count: usize = 0;

    inline for (cmds) |cmd| {
        arg_count += cmd.args.len;

        inline for (cmd.sub_cmds) |sub_cmd| {
            nested_cmd_count += 1;
            nested_arg_count += sub_cmd.args.len;
        }
    }

    try testing.expectEqual(cmds.len, app.context.cmds.len);
    try testing.expectEqual(2, nested_cmd_count);

    try testing.expectEqual(args.len, app.context.args.len);
    try testing.expectEqual(3, arg_count);
    try testing.expectEqual(1, nested_arg_count);
}
