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
            const sw = ansi.styledWriter(writer);
            for (self.text) |char| {
                if (std.ascii.isGraph(char) or char == ' ') {
                    try sw.print("{c}", .{char});
                }
                else {
                    try sw.background(.yellow);
                    try sw.write(" ");
                    try sw.noBackground();
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
        const sw = ansi.styledStdErr();
        try sw.italic();
        try sw.print("{s}:{d}:{d} ", .{token.source().path, token.line.index + 1, token.start + 1});
        try sw.none();
        try writePrefix(sw, level);
        try sw.print(fmt ++ "\n", args);
        try writeArrow(sw);
        const line_text = token.line.text();
        try sw.print("{}", .{ esc(line_text) });
        // if (token.start > 0) {
        //     try sw.print("{}", .{ esc(line_text[0..token.start]) });
        // }
        // try sw.background(.black_light);
        // try sw.print("{s}", .{ esc(token.text()) });
        // try sw.none();
        // const token_end = token.start + token.len;
        // if (token_end < line_text.len) {
        //     try sw.print("{}", .{ esc(line_text[token_end..]) });
        // }
        try sw.write("\n");
        if (token.len > 0) {
            try sw.writer.writeByteNTimes(' ', token.start + 5);
            try sw.bold();
            try sw.foreground(.magenta_light);
            try sw.writer.writeByteNTimes('^', token.len);
            try sw.none();
        }
        try sw.write("\n");
    }

    fn writeArrow(sw: anytype) !void {
        try sw.foreground(.black_light);
        try sw.write(" >>> ");
        try sw.noForeground();
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