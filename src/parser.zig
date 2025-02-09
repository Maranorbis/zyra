const std = @import("std");

const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;
const process = std.process;
const testing = std.testing;

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

pub const ParseError = error{ UnknownError, OutOfMemory, InvalidFlagValue };

pub const ArgParser = struct {
    allocator: Allocator,
    args: [][]u8,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        const args = try process.argsAlloc();

        return .{
            .allocator = allocator,
            .args = args,
        };
    }

    pub fn deinit(self: *Self) void {
        process.argsFree(self.allocator, self.args);
    }
};
