const std = @import("std");
const argument = @import("argument.zig");

const process = std.process;
const testing = std.testing;

const ArgIterator = process.ArgIterator;

const Flag = argument.Flag;
const Flags = []const argument.Flag;

const Positional = argument.Positional;
const Positionals = []const argument.Positional;

const Argument = argument.Argument;
const Arguments = []const argument.Argument;

fn ArgumentResult(comptime Args: Arguments) type {
    var fields: [Args.len]std.builtin.Type.StructField = undefined;

    for (Args, &fields) |arg, *dst| {
        const name = switch (arg.kind()) {
            .flag => arg.flag.long,
            .positional => std.fmt.comptimePrint(arg.positional.pos),
        };

        const value =
            switch (arg.kind()) {
            .flag => arg.flag.value,
            .positional => arg.positional.value,
        };

        dst.* = .{
            .name = name,
            .type = value,
            .alignment = @alignOf(value),
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

        pub fn parseArgs(self: *Self, args: []const [:0]const u8) !ArgumentResult(Args) {
            _ = self;

            var res: ArgumentResult(Args) = undefined;

            const FlagStatus = enum { found, not_found };

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

                    var status: FlagStatus = .not_found;
                    inline for (Args) |a| {
                        if (std.mem.eql(u8, name, a.flag.long) or
                            std.mem.eql(u8, name, a.flag.short))
                        {
                            status = .found;
                            @field(res, a.flag.long) = try parseValue(a.flag.value, &value);
                        }
                    }

                    if (status == .not_found) return error.NotFound;
                }
            }

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

    try testing.expect(res.show);
    try testing.expect(res.gobble);
    try testing.expect(res.double_gobble);
    try testing.expect(res.help == false);
    try testing.expectEqual(res.value, 20);
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
