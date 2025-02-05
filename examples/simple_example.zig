const std = @import("std");
const process = std.process;
const zyra = @import("zyra");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            @panic("Fatal: Memory leak detected!");
        }
    }
    const allocator = gpa.allocator();

    var parser = zyra.Parser.init(allocator);
    defer parser.deinit();

    var it = process.argsWithAllocator(allocator) catch {
        try std.fmt.format(std.io.getStdErr().writer(), "Unable to allocate memory for ArgIterator\n.", .{});
    };
    defer it.deinit();

    try parser.parse(&it);

    const writer = std.io.getStdOut().writer();

    try writer.writeAll("Flags:\n");
    for (parser.context.flags.items) |f| {
        try std.fmt.format(std.io.getStdErr().writer(), "\t{s}\n", .{f});
    }

    try writer.writeAll("\nPositonals:\n");
    for (parser.context.positionals.items) |p| {
        try std.fmt.format(std.io.getStdErr().writer(), "\t{s}\n", .{p});
    }
}
