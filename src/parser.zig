const std = @import("std");
const argument = @import("argument.zig");

const process = std.process;
const testing = std.testing;

const ArgIterator = process.ArgIterator;

const Argument = argument.Argument;
const Arguments = []const argument.Argument;

pub fn ArgumentResult(comptime Args: Arguments) type {
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

        // pub fn parseIt(self: *Self, it: *ArgIterator) !ArgumentResult(Args) {
        //     var res: ArgumentResult(Args) = undefined;
        //
        //     _ = it.skip();
        //
        //     while (it.next()) |arg| {
        //         if (std.mem.lastIndexOfScalar(u8, '-', arg)) |idx| {
        //             // if (arg.len <= (idx + 1)) return error.ParseError;
        //             // const sepIdx = std.mem.indexOfScalar(u8, '=', arg);
        //             // const name = arg[idx + 1 .. sepIdx];
        //             // inline for (Args) |a| {}
        //         }
        //     }
        //
        //     return res;
        // }

        pub fn parseArgs(self: *Self, args: []const [:0]const u8) !ArgumentResult(Args) {
            _ = self;

            var res: ArgumentResult(Args) = undefined;

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

                    // TODO: Handle unknown flag cases, return error if an invalid flag is provided
                    inline for (Args) |a| {
                        if (std.mem.eql(u8, name, a.flag.long) or
                            std.mem.eql(u8, name, a.flag.short))
                        {
                            @field(res, a.flag.long) = try parseValue(a.flag.value, &value);
                        }
                    }
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
    };

    const osArgs = &.{ "app", "--test", "--value=20", "-s=true" };

    var parser = Parser(args).default;
    const res = try parser.parseArgs(osArgs);

    try testing.expect(res.show);
    try testing.expect(res.help == false);
    try testing.expectEqual(res.value, 20);
}
