pub const argument = @import("argument.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
