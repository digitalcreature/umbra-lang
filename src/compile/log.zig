const std = @import("std");

usingnamespace @import("util");

usingnamespace @import("context.zig");
usingnamespace @import("unit.zig");
usingnamespace @import("source.zig");


pub const Log = struct {

    pub const Level = enum {
        err,
        warn,
    };

    const Self = @This();

    pub fn logSourceToken(self: *Self, comptime level: Level, token: Source.Token, comptime fmt: []const u8, args: anytype) !void {
        const writer = std.io.getStdErr().writer();
        try ansi.printEscaped(writer, "3", "{s}:{d}:{d}", .{token.source().path, token.line.index + 1, token.start + 1});
        try writer.writeAll(" ");
        try self.writePrefix(level);
        const line_text = token.line.text;
        try writer.print(fmt ++ "\n", args);
        try ansi.printEscaped(writer, "90", " >>> ", .{});
        if (token.start > 0) {
            try writer.writeAll(line_text[0..token.start]);
        }
        try ansi.printEscaped(writer, "100", "{s}", .{token.text()});
        const token_end = token.start + token.len;
        if (token_end < line_text.len) {
            try writer.writeAll(line_text[token_end..]);
        }
        try writer.writeAll("\n\n");
    }

    fn writePrefix(self: *Self, comptime level: Level) !void {
        const writer = std.io.getStdErr().writer();
        switch (level) {
            .err => try ansi.printEscaped(writer, "91", "error", .{}),
            .warn => try ansi.printEscaped(writer, "38;5;164", "warning", .{}),
        }
        try writer.writeAll(": ");
    }

};