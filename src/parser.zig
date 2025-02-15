const std = @import("std");
const argument = @import("argument.zig");

const fmt = std.fmt;
const process = std.process;
const testing = std.testing;

const Type = std.builtin.Type;
const ArgIterator = process.ArgIterator;

const Argument = argument.Argument;
const Arguments = []const argument.Argument;

pub const ParseError = error{ OutOfMemory, NotFound, Value, InvalidFlag };

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

        pub fn report(self: *Self, comptime writer: anytype) !void {
            if (!self.state.failed) return error.NonFailureReport;

            writer.writeAll(self.state.message);
        }

        pub fn parseArgs(self: *Self, args: []const [:0]const u8) ParseError!ParseResult(Args) {
            var flagRes: FlagResult(Args) = undefined;
            var posRes: PositionalResult(Args) = undefined;

            // Index to keep track of which positional parameter we will be searching and parsing the value for.
            var posIdx: usize = 0;

            for (args[1..]) |arg| {
                if (std.mem.lastIndexOfScalar(u8, arg, '-')) |idx| {
                    if (idx > 1) {
                        self.failure(
                            \\Invalid Flag provided, flags are generally provided using a single `-` or double `--`.
                            \\
                            \\ Correct Example: --help or -h
                            \\ Wrong Example: ---help, ---h or h (this is considered a positional/command parameter).
                        );

                        return ParseError.InvalidFlag;
                    }

                    parseFlag(Args, self, &flagRes, &arg, idx);

                    if (self.failed) return ParseError.NotFound;
                } else {
                    parsePositional(Args, self, &posRes, &arg, posIdx);
                    if (self.failed) return ParseError.NotFound;

                    posIdx += 1;
                }
            }

            var res: ParseResult(Args) = undefined;

            res.flags = flagRes;
            res.positionals = posRes;

            return res;
        }
    };
}

fn parseValue(comptime T: type, value: *const [:0]const u8) ParseError!T {
    return switch (T) {
        isize => {
            return std.fmt.parseInt(isize, value.*, 10) catch {
                return ParseError.Value;
            };
        },
        usize => {
            return std.fmt.parseInt(usize, value.*, 10) catch {
                return ParseError.Value;
            };
        },
        bool => {
            if (std.ascii.eqlIgnoreCase("true", value.*) or
                std.mem.eql(u8, "1", value.*)) return true;

            if (std.ascii.eqlIgnoreCase("false", value.*) or
                std.mem.eql(u8, "0", value.*)) return false;

            return ParseError.Value;
        },
        []const u8 => value.*,
        else => ParseError.Value,
    };
}

fn parseFlag(comptime Args: Arguments, parser: *Parser(Args), res: *FlagResult(Args), arg: *const [:0]const u8, idx: usize) void {
    // Find the first occurrence of '=' in the argument, which separates the flag name from its value.
    // If '=' is not found, use the full length of `arg` (i.e., no explicit value provided).
    const sep_idx = std.mem.indexOfScalar(u8, arg.*, '=') orelse arg.*.len;

    // Extract the flag name, skipping the '-' prefix but stopping at '=' if present otherwise the full
    // argument (except for `-` or `--`) is taken as name.
    const name = arg.*[idx + 1 .. sep_idx];

    // Determine the flag value:
    //
    // - If '=' exists and there are characters after it, extract them as value.
    // - Otherwise, use `"1"` as the default value (indicating the presence of flag).
    const value = if (sep_idx < arg.*.len - 1) arg.*[sep_idx + 1 ..] else "1";

    inline for (Args) |a| {
        const isFlag = comptime blk: {
            break :blk a.kind() == .flag;
        };

        if (!isFlag) break;

        if (std.mem.eql(u8, name, a.flag.long) or
            std.mem.eql(u8, name, a.flag.short))
        {
            @field(res.*, a.flag.long) = parseValue(a.flag.value, &value) catch {
                parser.failure("Flag `" ++ a.flag.long ++ "` contains an invalid value of type `" ++ @typeName(a.flag.value) ++ "`");
                return;
            };

            return;
        }
    }

    parser.failure("Unknown Flag provided");
}

fn parsePositional(
    comptime Args: Arguments,
    parser: *Parser(Args),
    res: *PositionalResult(Args),
    arg: *const [:0]const u8,
    idx: usize,
) void {
    inline for (Args) |a| {
        const isPositional = comptime blk: {
            break :blk a.kind() == .positional;
        };

        if (!isPositional) break;

        if (idx == a.positional.pos) {
            const name = fmt.comptimePrint("{d}", .{a.positional.pos});
            @field(res.*, name) = parseValue(a.positional.value, arg) catch {
                parser.failure(
                    "Positonal parameter `" ++ name ++ "` contains an invalid value, expected `" ++ @typeName(a.positional.value) ++ "`",
                );
                return;
            };

            return;
        }
    }

    parser.failure("Invalid positional parameter");
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

    try testing.expectError(ParseError.NotFound, parser.parseArgs(osArgs));
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
}
