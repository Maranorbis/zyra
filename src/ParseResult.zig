const ParseResult = @This();

const std = @import("std");
const flag = @import("flag.zig");

const Allocator = std.mem.Allocator;

const FlagValueMap = flag.FlagValueMap;
const PositionalArray = std.ArrayList([:0]const u8);

allocator: Allocator,
flags: FlagValueMap,
positionals: PositionalArray,

pub fn init(allocator: Allocator) ParseResult {
    return .{
        .allocator = allocator,
        .flags = FlagValueMap.init(allocator),
        .positionals = PositionalArray.init(allocator),
    };
}

pub fn deinit(self: *ParseResult) void {
    self.flags.deinit();
    self.positionals.deinit();
}
