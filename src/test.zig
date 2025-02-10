pub const parser = @import("parser.zig");
pub const flag = @import("flag.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
