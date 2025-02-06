const Parser = @This();

const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

const FlagParamsArray = std.ArrayList([]const u8);
const PositionalParamsArray = std.ArrayList([]const u8);

/// Symbols is a namespace which includes constants values that are used as identifiers by Parser.
const Symbols = struct {
    const Flag = enum(u8) {
        identifier = '-',
        separator = '=',
    };
};

pub const Error = error{ UnknownError, OutOfMemory };

pub const Context = struct {
    flags: FlagParamsArray,
    positionals: PositionalParamsArray,

    const Self = @This();

    pub fn deinit(self: Self) void {
        self.flags.deinit();
        self.positionals.deinit();
    }
};

allocator: Allocator,
context: Context = undefined, // We will initialize this later but obtain a pointer to the memory address for now.

pub fn init(allocator: Allocator) Parser {
    return .{
        .allocator = allocator,
    };
}

pub fn parse(self: *Parser, it: *ArgIterator) Error!void {
    var context: Context = .{
        .flags = FlagParamsArray.init(self.allocator),
        .positionals = PositionalParamsArray.init(self.allocator),
    };

    _ = it.skip();

    while (it.next()) |arg| {
        if (arg[0] == @intFromEnum(Symbols.Flag.identifier)) {
            try context.flags.append(arg);
        } else {
            try context.positionals.append(arg);
        }
    }

    self.context = context;
}

pub fn deinit(self: *Parser) void {
    self.context.deinit();
}
