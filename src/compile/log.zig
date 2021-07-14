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
        const sw = ansi.styledStdErr();
        try sw.italic();
        try sw.print("{s}:{d}:{d} ", .{token.source().path, token.line.index + 1, token.start + 1});
        try sw.none();
        try writePrefix(sw, level);
        try sw.print(fmt ++ "\n", args);
        const line_text = token.line.text();
        try sw.foreground(.black_light);
        try sw.write(" >>> ");
        try sw.noForeground();
        if (token.start > 0) {
            try writer.print("{}", .{ esc(line_text[0..token.start]) });
        }
        try sw.background(.black_light);
        try sw.print("{s}", .{ esc(token.text()) });
        try sw.none();
        const token_end = token.start + token.len;
        if (token_end < line_text.len) {
            try sw.print("{}", .{ esc(line_text[token_end..]) });
        }
        try sw.write("\n\n");
    }

    fn writePrefix(sw: anytype, comptime level: Level) !void {
        switch (level) {
            .err => {
                try sw.foreground(.red_light);
                try sw.write("error");
            },
            .warn => {
                try sw.foreground(.yellow_light);
                try sw.write("warning");
            },
        }
        try sw.none();
        try sw.write(": ");
    }

};