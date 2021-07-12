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