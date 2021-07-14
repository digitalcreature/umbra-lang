const std = @import("std");

usingnamespace @import("util");

usingnamespace @import("context.zig");
usingnamespace @import("unit.zig");
usingnamespace @import("source.zig");


pub const log = struct {

    pub const Level = enum {
        err,
        warn,
    };

    const Self = @This();
    
    const EscapedString = struct {
        
        text: []const u8,

        pub fn format(self: EscapedString, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            for (self.text) |char| {
                if (std.ascii.isGraph(char) or char == ' ') {
                    try writer.writeByte(char);
                }
                else {
                    try writer.writeByte(' ');
                }
            }
        }


    };

    pub fn esc(text: []const u8) EscapedString {
        return EscapedString{
            .text = text,
        };
    }

    pub fn logSourceToken(comptime level: Level, token: Source.Token, comptime fmt: []const u8, args: anytype) !void {
        const writer = std.io.getStdErr().writer();
        try ansi.printEscaped(writer, "3", "{s}:{d}:{d}", .{token.source().path, token.line.index + 1, token.start + 1});
        try writer.writeAll(" ");
        try writePrefix(level);
        try writer.print(fmt ++ "\n", args);
        const line_text = token.line.text();
        try ansi.printEscaped(writer, "90", " >>> ", .{});
        if (token.start > 0) {
            try writer.print("{}", .{ esc(line_text[0..token.start]) });
        }
        try ansi.printEscaped(writer, "100", "{s}", .{ esc(token.text()) });
        const token_end = token.start + token.len;
        if (token_end < line_text.len) {
            try writer.print("{}", .{ esc(line_text[token_end..]) });
        }
        try writer.writeAll("\n");
        try writer.writeAll("\n");
    }

    fn writePrefix(comptime level: Level) !void {
        const writer = std.io.getStdErr().writer();
        switch (level) {
            .err => try ansi.printEscaped(writer, "91", "error", .{}),
            .warn => try ansi.printEscaped(writer, "38;5;164", "warning", .{}),
        }
        try writer.writeAll(": ");
    }

};