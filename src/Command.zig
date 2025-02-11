const Command = @This();

const std = @import("std");
const flag = @import("flag.zig");
const Parser = @import("Parser.zig");
const ParseResult = @import("ParseResult.zig");

const testing = std.testing;

const Flag = flag.Flag;
const FlagMap = std.StaticStringMap(Flag);
const FlagMapEntry = struct { []const u8, Flag };

const CommandMap = std.StaticStringMap(Command);
const CommandMapEntry = struct { []const u8, Command };

pub const Handler = *const fn (*ParseResult) void;

pub const CommandError = error{DoesNotExist};

name: [:0]const u8,
handler: Handler,
flagMap: FlagMap = undefined,
commandMap: CommandMap = undefined,

pub fn init(
    comptime name: [:0]const u8,
    comptime handler: Handler,
    comptime flags: []const Flag,
    comptime commands: []const Command,
) Command {
    const flag_kvs = comptime flag: {
        const len = flags.len * 2; // each `Flag` will have 2 entries, one for `long` the other for `short`
        var arr: [len]FlagMapEntry = undefined;

        for (flags, 0..) |f, i| {
            arr[i] = .{ f.long, f };
            arr[i + flags.len] = .{ f.short, f };
        }

        break :flag arr[0..];
    };

    const command_kvs = comptime cmds: {
        const len = commands.len;
        var arr: [len]CommandMapEntry = undefined;

        for (commands, 0..) |cmd, i| {
            arr[i] = .{ cmd.name, cmd };
        }

        break :cmds arr[0..];
    };

    return .{
        .name = name,
        .handler = handler,
        .flagMap = FlagMap.initComptime(flag_kvs),
        .commandMap = CommandMap.initComptime(command_kvs),
    };
}

pub fn hasCommand(self: *Command, cmd: []const u8) bool {
    if (self.commandMap.get(cmd) != null) {
        return true;
    }

    return false;
}

pub fn getCommand(self: *Command, name: []const u8) CommandError!Command {
    return self.commandMap.get(name) orelse CommandError.DoesNotExist;
}

pub fn run(self: *Command, parser: *Parser, args: []const [:0]const u8) void {
    var cmd = self;

    var idx: usize = 1;

    while (idx < args.len - 1) {
        if (cmd.hasCommand(args[idx])) {
            var c = cmd.getCommand(args[idx]) catch {
                @panic("Unhandled case, command not found. Panicking");
            };

            cmd = &c;
            idx += 1;
        }
    }

    var res = parser.parse(args[idx..], cmd.flagMap) catch {
        @panic("Unhandled case, ParseError. Panicking from run method of command");
    };

    cmd.handler(&res);
}

fn testCmdHandler(res: *ParseResult) void {
    _ = res;
}

test "Command initializes" {
    const cmd = Command.init("test", &testCmdHandler, &.{}, &.{});

    try testing.expectEqual(cmd.flagMap.kvs.len, 0);
    try testing.expectEqual(cmd.commandMap.kvs.len, 0);
    try testing.expectEqualStrings("test", cmd.name);
}

test "Command initializes with Flags" {
    const cmd = Command.init("test", &testCmdHandler, &.{
        Flag{ .long = "help", .short = "h" },
        Flag{ .long = "version", .short = "v" },
    }, &.{});

    try testing.expectEqual(cmd.flagMap.kvs.len, 4);
    try testing.expectEqual(cmd.commandMap.kvs.len, 0);
    try testing.expectEqualStrings("test", cmd.name);
}

test "Command initializes with Sub Commands" {
    const cmd = Command.init("test", &testCmdHandler, &.{}, &.{
        Command.init("help", &testCmdHandler, &.{}, &.{}),
        Command.init("version", &testCmdHandler, &.{}, &.{}),
    });

    try testing.expectEqual(cmd.flagMap.kvs.len, 0);
    try testing.expectEqual(cmd.commandMap.kvs.len, 2);
}

test "Command initializes with both Sub Commands and Flags" {
    const cmd = Command.init("test", &testCmdHandler, &.{
        Flag{ .long = "help", .short = "h" },
        Flag{ .long = "version", .short = "v" },
    }, &.{
        Command.init("help", &testCmdHandler, &.{}, &.{}),
        Command.init("version", &testCmdHandler, &.{}, &.{}),
    });

    try testing.expectEqual(cmd.flagMap.kvs.len, 4);
    try testing.expectEqual(cmd.commandMap.kvs.len, 2);
}
