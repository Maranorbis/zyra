const std = @import("std");
const argument = @import("argument.zig");

const fmt = std.fmt;
const process = std.process;
const testing = std.testing;

const Type = std.builtin.Type;
const ArgIterator = process.ArgIterator;

const Argument = argument.Argument;
const Arguments = []const argument.Argument;

pub fn ParseResult(comptime Args: Arguments) type {
    return struct {
        flags: FlagResult(Args),
        positionals: PositionalResult(Args),
    };
}

fn FlagResult(comptime Args: Arguments) type {
    const len = comptime blk: {
        var count: usize = 0;

        for (Args) |arg| {
            if (arg.kind() == .flag) count += 1;
        }

        break :blk count;
    };

    if (len == 0) {
        return @Type(.{ .Struct = .{
            .layout = .auto,
            .fields = &.{},
            .decls = &.{},
            .is_tuple = false,
        } });
    }

    var fields: [len]Type.StructField = undefined;
    for (Args, &fields) |arg, *dst| {
        if (arg.kind() == .positional) continue;

        dst.* = .{
            .name = arg.flag.long,
            .type = arg.flag.value,
            .alignment = @alignOf(arg.flag.value),
            .is_comptime = false,
            .default_value = null,
        };
    }

    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

fn PositionalResult(comptime Args: Arguments) type {
    const len = comptime blk: {
        var count: usize = 0;

        for (Args) |arg| {
            if (arg.kind() == .positional) count += 1;
        }

        break :blk count;
    };

    if (len == 0) {
        return @Type(.{ .Struct = .{
            .layout = .auto,
            .fields = &.{},
            .decls = &.{},
            .is_tuple = false,
        } });
    }

    var fields: [len]Type.StructField = undefined;
    for (Args, &fields) |arg, *dst| {
        if (arg.kind() == .flag) continue;

        dst.* = .{
            .name = fmt.comptimePrint("{d}", .{arg.positional.pos}),
            .type = arg.positional.value,
            .alignment = @alignOf(arg.positional.value),
            .is_comptime = false,
            .default_value = null,
        };
    }

    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

pub fn Parser(comptime Args: Arguments) type {
    return struct {
        const Self = @This();

        failed: bool,
        message: []const u8,

        pub const default: Self = .{
            .failed = false,
            .message = "",
        };

        pub fn failure(self: *Self, message: []const u8) void {
            self.failed = true;
            self.message = message;
        }

        pub fn reset(self: *Self) void {
            self.* = default;
        }

        pub fn report(self: *Self, comptime writer: anytype) !void {
            if (!self.state.failed) return error.NonFailureReport;

            writer.writeAll(self.state.message);
        }

        pub fn parseArgs(self: *Self, args: []const [:0]const u8) !ParseResult(Args) {
            _ = self;

            const ArgStatus = enum { found, not_found };

            var flagRes: FlagResult(Args) = undefined;
            var posRes: PositionalResult(Args) = undefined;

            var posIdx: usize = 0;

            for (args[1..]) |arg| {
                if (std.mem.lastIndexOfScalar(u8, arg, '-')) |idx| {
                    if (idx > 1) return error.ParseError;

                    // Find the first occurrence of '=' in the argument, which separates the flag name from its value.
                    // If '=' is not found, use the full length of `arg` (i.e., no explicit value provided).
                    const sep_idx = std.mem.indexOfScalar(u8, arg, '=') orelse arg.len;

                    // Extract the flag name, skipping the '-' prefix but stopping at '=' if present otherwise the full
                    // argument (except for `-` or `--`) is taken as name.
                    const name = arg[idx + 1 .. sep_idx];

                    // Determine the flag value:
                    //
                    // - If '=' exists and there are characters after it, extract them as value.
                    // - Otherwise, use `"1"` as the default value (indicating the presence of flag).
                    const value = if (sep_idx < arg.len - 1) arg[sep_idx + 1 ..] else "1";

                    var status: ArgStatus = .not_found;
                    inline for (Args) |a| {
                        if (status == .found) break;

                        const isFlag = comptime blk: {
                            break :blk a.kind() == .flag;
                        };

                        if (!isFlag) break;

                        if (std.mem.eql(u8, name, a.flag.long) or
                            std.mem.eql(u8, name, a.flag.short))
                        {
                            status = .found;
                            @field(flagRes, a.flag.long) = try parseValue(a.flag.value, &value);
                        }
                    }

                    if (status == .not_found) return error.NotFound;
                } else {
                    var status: ArgStatus = .not_found;
                    inline for (Args) |a| {
                        if (status == .found) break;

                        const isPositional = comptime blk: {
                            break :blk a.kind() == .positional;
                        };

                        if (!isPositional) break;

                        if (posIdx == a.positional.pos) {
                            status = .found;

                            const name = fmt.comptimePrint("{d}", .{a.positional.pos});
                            @field(posRes, name) = try parseValue(a.positional.value, &arg);

                            posIdx += 1;
                        }
                    }
                }
            }

            var res: ParseResult(Args) = undefined;

            res.flags = flagRes;
            res.positionals = posRes;

            return res;
        }
    };
}

fn parseValue(comptime T: type, value: *const [:0]const u8) !T {
    return switch (T) {
        usize => {
            return std.fmt.parseInt(usize, value.*, 10) catch {
                return error.ValueParseError;
            };
        },
        bool => {
            if (std.ascii.eqlIgnoreCase("true", value.*) or
                std.mem.eql(u8, "1", value.*)) return true;

            if (std.ascii.eqlIgnoreCase("false", value.*) or
                std.mem.eql(u8, "0", value.*)) return false;

            return error.ValueParseError;
        },
        else => error.ValueParseError,
    };
}

test "Parser" {
    const args = &.{
        Argument.Factory.flag("help", "h"),
        Argument.Factory.valueFlag(usize, "value", "v"),
        Argument.Factory.valueFlag(bool, "show", "s"),
        Argument.Factory.valueFlag(bool, "gobble", "g"),
        Argument.Factory.valueFlag(bool, "double_gobble", "g"),
    };

    const osArgs = &.{ "app", "--value=20", "-s=true", "-g", "--double_gobble" };

    var parser = Parser(args).default;
    const res = try parser.parseArgs(osArgs);

    try testing.expect(res.flags.show);
    try testing.expect(res.flags.gobble);
    try testing.expect(res.flags.double_gobble);
    try testing.expect(res.flags.help == false);
    try testing.expectEqual(res.flags.value, 20);
}

test "Parser returns NotFound if an unknown Flag is provided" {
    const args = &.{
        Argument.Factory.flag("help", "h"),
        Argument.Factory.valueFlag(usize, "value", "v"),
        Argument.Factory.valueFlag(bool, "show", "s"),
    };

    // `--test` flag is not defined in the arg list above.
    const osArgs = &.{ "app", "--test", "--value=20", "-s=true" };

    var parser = Parser(args).default;

    try testing.expectError(error.NotFound, parser.parseArgs(osArgs));
}

test "Parser parses positional argument" {
    const args = &.{
        Argument.Factory.positional(bool, 0),
        Argument.Factory.positional(usize, 1),
    };

    const osArgs = &.{ "app", "true", "20" };

    var parser = Parser(args).default;

    const res = try parser.parseArgs(osArgs);

    try testing.expect(res.positionals.@"0");
    try testing.expectEqual(20, res.positionals.@"1");
}
