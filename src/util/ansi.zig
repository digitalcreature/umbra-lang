const std = @import("std");

/// replace characters in fmt to implement ansi sgr escape sequences
/// any instance of `%(?)` with `\x1b[?m`, where `?` is any sequence of
/// specifiers. any sequence matching `/[0-9 ;]*/` is allowed.
/// specifier reference:
/// https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
pub fn esc(comptime fmt: []const u8) []const u8 {
    comptime {
        var result: [fmt.len]u8 = undefined;
        var i: usize = 0;
        while (i < fmt.len) : (i += 1) {
            if ((i + 1 < fmt.len) and std.mem.eql(u8, fmt[i..(i + 2)], "%(")) {
                result[i] = '\x1b';
                result[i+1] = '[';
                i += 2;
                while (i < fmt.len) : (i += 1) {
                    switch (fmt[i]) {
                        ')' => {
                            result[i] = 'm';
                            break;
                        },
                        '0'...'9', ' ', ';' => |char| result[i] = char,
                        else => |char| @compileError("invalid character '" ++ &[1]u8{char} ++ "'"),
                    }
                }
                else @compileError("missing closing '')' in ansi escape format string");
            }
            else {
                result[i] = fmt[i];
            }
        }
        return &result;
    }
}

pub fn writerSupportsEscapes(writer: anytype) bool {
    if (@TypeOf(writer) == std.fs.File.Writer) {
        const handle = writer.context.handle;
        return (
            // on windows, supportsAnsiEscapeCodes is unreliabled
            // so we assume escapes are valid if we are printing to stderr
            handle == std.io.getStdErr().handle or
            writer.context.supportsAnsiEscapeCodes()
        );
    }
    else {
        return false;
    }
}

/// removes ansi escapes from a format string
pub fn cleanEsc(comptime fmt: []const u8) []const u8 {
    comptime {
        var result: [fmt.len]u8 = undefined;
        var len: usize = 0;
        var i: usize = 0;
        while (i < fmt.len) : (i += 1) {
            if ((i + 1 < fmt.len) and std.mem.eql(u8, fmt[i..(i + 2)], "%(")) {
                i += 2;
                while (i < fmt.len) : (i += 1) {
                    switch (fmt[i]) {
                        ')' => {
                            break;
                        },
                        '0'...'9', ' ', ';' => {},
                        else => |char| @compileError("invalid character '" ++ &[1]u8{char} ++ "'"),
                    }
                }
                else @compileError("missing closing '')' in ansi escape format string");
            }
            else {
                result[len] = fmt[i];
                len += 1;
            }
        }
        return result[0..len];
    }
}

pub fn printEscaped(writer: anytype, comptime style: []const u8, comptime fmt: []const u8, args: anytype) !void {
    if (writerSupportsEscapes(writer)) {
        try writer.print(comptime esc("%(" ++ style ++ ")" ++ fmt ++ "%(0)"), args);
    }
    else {
        try writer.print(comptime cleanEsc(fmt), args);
    }
}


pub const Style = enum(u8) {
    
    none = 0,
    
    bold = 1,
    italic = 3,
    underline = 4,
    invert = 7,
    strike = 9,

    no_bold = 22,
    no_italic = 23,
    no_underline = 24,
    no_invert = 27,
    no_strike = 29,

};

pub const Color = enum(u8) {

    default = 39,

    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,

    black_light = 90,
    red_light = 91,
    green_light = 92,
    yellow_light = 93,
    blue_light = 94,
    magenta_light = 95,
    cyan_light = 96,
    white_light = 97,

};

pub fn StyledWriter(comptime writer_type: type) type {
    return struct {

        writer: Writer,

        pub const Writer = writer_type;

        const Self = @This();

        fn esc(self: Self, numbers: []const u8) !void {
            try self.write("\x1b[");
            for (numbers) |number, i| {
                if (i > 0) {
                    try self.write(";");
                }
                try self.print("{d}", .{number});
            }
            try self.write("m");
        }
        pub fn write(self: Self, text: []const u8) !void {
            try self.writer.writeAll(text);
        }

        pub fn print(self: Self, comptime fmt: []const u8, args: anytype) !void {
            try self.writer.print(fmt, args);
        }

        pub fn style(self: Self, s: Style) !void { try self.esc(&.{ @enumToInt(s) }); }
        pub fn styles(self: Self, ss: []const Style) !void {
            for (ss) |s| {
                try self.style(s);
            }
        }

        pub fn none(self: Self) !void { try self.style(.none); }
        pub fn bold(self: Self) !void { try self.style(.bold); }
        pub fn italic(self: Self) !void { try self.style(.italic); }
        pub fn underline(self: Self) !void { try self.style(.underline); }
        pub fn invert(self: Self) !void { try self.style(.invert); }
        pub fn strike(self: Self) !void { try self.style(.strike); }
        
        pub fn noBold(self: Self) !void { try self.style(.no_bold); }
        pub fn noItalic(self: Self) !void { try self.style(.no_italic); }
        pub fn noUnderline(self: Self) !void { try self.style(.no_underline); }
        pub fn noInvert(self: Self) !void { try self.style(.no_invert); }
        pub fn noStrike(self: Self) !void { try self.style(.no_strike); }

        pub fn colors(self: Self, fore: ?Color, back: ?Color) !void {
            if (fore) |fg| {
                try self.esc(&.{@enumToInt(fg)});
            }
            if (back) |bg| {
                try self.esc(&.{@enumToInt(bg) + 10});
            }
        }

        pub fn noColors(self: Self) !void { try self.colors(.default, .default); }

        pub fn foreground(self: Self, col: Color) !void { try self.colors(col, null); }
        pub fn background(self: Self, col: Color) !void { try self.colors(null, col); }
        
        pub fn noForeground(self: Self) !void { try self.colors(.default, null); }
        pub fn noBackground(self: Self) !void { try self.colors(null, .default); }


    };
}

pub fn styledWriter(writer: anytype) StyledWriter(@TypeOf(writer)) {
    return StyledWriter(@TypeOf(writer)){ .writer = writer };
}

pub const StyledFileWriter = StyledWriter(std.fs.File.Writer);

pub fn styledStdErr() StyledFileWriter {
    return styledWriter(std.io.getStdErr().writer());
}