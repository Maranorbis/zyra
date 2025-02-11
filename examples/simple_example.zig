const std = @import("std");
const zyra = @import("zyra");

const process = std.process;

fn appHandler(res: *zyra.ParseResult) void {
    defer res.deinit();

    std.debug.print("Hello {?s}\n", .{res.positionals.getLastOrNull()});
}

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

    var app = zyra.Command.init("say", &appHandler, &.{}, &.{});

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    app.run(&parser, args);
}
