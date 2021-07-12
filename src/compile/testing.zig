const std = @import("std");

usingnamespace @import("source.zig");
usingnamespace @import("context.zig");
usingnamespace @import("unit.zig");
usingnamespace @import("token.zig");
usingnamespace @import("lexer.zig");


pub usingnamespace std.testing;

pub fn createTestingContext() !*Context {
    return Context.create(allocator);
}

pub fn createTestingUnit(source: Source) !*Unit {
    const context = try Context.create(allocator);
    errdefer context.destroy();
    return context.addUnit(source);
}

pub fn createTestingUnitFromFile(path: []const u8) !*Unit {
    const context = try Context.create(allocator);
    errdefer context.destroy();
    return context.addUnitFromFile(path);
}

// pub fn createTestingUnitFromEmbed(comptime zsl: std.builtin.SourceLocation, text: []const u8) !*Unit {
//     const context = try Context.create(allocator);
//     errdefer context.destroy();
//     return context.addUnitFromEmbed(zsl, text);
// }