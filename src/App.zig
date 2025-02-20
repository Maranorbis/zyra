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

test "App" {
    const name = "test_app";
    const desc = "just for testing";

    const app = Self.init(.{ .name = name, .desc = desc }, .{});

    try testing.expectEqualStrings(name, app.info.name);
    try testing.expectEqualStrings(desc, app.info.desc);
    try testing.expectEqual(0, app.context.args.len);
    try testing.expectEqual(0, app.context.cmds.len);

    const bare_app = Self.init(.{ .name = name }, .{});

    try testing.expectEqualStrings(name, bare_app.info.name);
    try testing.expectEqualStrings("", bare_app.info.desc);
    try testing.expectEqual(0, bare_app.context.args.len);
    try testing.expectEqual(0, bare_app.context.cmds.len);
}
