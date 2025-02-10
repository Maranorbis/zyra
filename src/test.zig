pub const parser = @import("parser.zig");
pub const flag = @import("flag.zig");
pub const Command = @import("Command.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
