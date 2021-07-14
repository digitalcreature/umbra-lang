// pub usingnamespace @import("~token.zig");
const std = @import("std");
usingnamespace @import("util");

usingnamespace @import("source.zig");
usingnamespace @import("log.zig");

const Allocator = std.mem.Allocator;


pub const Token = struct {

    class: Class,
    text: []const u8,
    line: Source.Line,

    pub const Class = enum {

        invalid,

        symbol,
        name,
        keyword,
        builtin,
        number,

        comment,
        space,
        line_end,
    
    };

    const Self = @This();

    pub fn sourceToken(self: Self) Source.Token {
        return self.line.tokenFromSlice(self.text);
    }

    pub const keywords = [_][]const u8{
        "let",
        "vert",
        "frag",
        "out",
    };

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        if (self.class == .line_end) {
            try writer.writeByte('\n');
        }
        else {
            inline for (comptime std.enums.values(Class)) |class| {
                if (class == self.class) {
                    const style = switch(class) {
                        .invalid => "101;30",
                        .symbol => "33",
                        .name => "32",
                        .keyword => "94",
                        .builtin => "96",
                        .number => "35",
                        .comment => "3;38;5;238",
                        else => "",
                    };
                    try ansi.printEscaped(writer, style, "{}", .{ log.esc(self.text) });
                }

            }
        }
    }

};

pub const TokenStream = struct {

    source: Source.Ptr,

    token: Token,
    rest_text: []const u8,
    
    log_errors: bool = true,

    const Self = @This();

    pub fn initFromSource(source: Source.Ptr) Self {
        return init(source, source.text);
    }

    pub fn iniFromLine(line: Source.Line) Self {
        return init(line.source, line.text());
    }

    fn init(source: Source.Ptr, text: []const u8) Self {
        var token_text: []const u8 = source.text;
        token_text.len = 0;
        return Self {
            .source = source,
            .rest_text = text,
            .token = Token {
                .class = .invalid,
                .text = token_text,
                .line = Source.Line {
                    .source = source,
                    .index = 0,
                    .start = 0,
                },
            },
        };
    }

    pub fn deinit(self: *Self) void { }

    /// advance stream index by `len`
    /// if remaining text is shorter than `len`, advance to the end
    fn advance(self: *Self, len: usize) void {
        const actual_len = std.math.min(len, self.rest_text.len);
        if (self.token.text.len == 0) {
            self.token.text = self.rest_text[0..actual_len];
        }
        else {
            self.token.text.len += actual_len;
        }
        self.rest_text = self.rest_text[actual_len..];
    }

    /// consume and return the next up to `len` characters of the remaining text
    /// if remaining text is shorter than len, consume and return the entire remaining text
    fn read(self: *Self, len: usize) []const u8 {
        const result = self.peek(len);
        defer self.advance(result.len);
        return result;
    }

    /// return the next `len` available characters of the remaining text
    /// if remaining text is shorter than len, return the entire remaining text
    /// no text is consumed, the index does not move
    fn peek(self: Self, len: usize) []const u8 {
        const actual_len = std.math.min(len, self.rest_text.len);
        return self.rest_text[0..actual_len];
    }

    pub fn next(self: *Self) ?Token {
        if (self.rest_text.len == 0) {
            return null;
        }
        else {
            self.advance(1);
            const char = self.token.text[0];
            switch (char)  {
                
                0 => return self.emitInvalid("null byte", .{}),

                '\n', '\r' => {
                    if (char == '\n' or self.matchOptionalString("\n")) {
                        return self.emit(.line_end);
                    }
                    else {
                        return self.emitInvalid("lone carriage return", .{});
                    }
                },

                '\t' => return self.emitInvalid("tab characters are not allowed", .{}),

                ' ' => {
                    _ = self.matchManyChar(' ');
                    return self.emit(.space);
                },

                '`' => {
                    _ = self.matchManyClass(charclass.notLineEnd);
                    return self.emit(.comment);
                },

                '(', ')', '{', '}',
                ',', '.', ':',
                '+', '-', '*', '/', '=',
                    => return self.emit(.symbol),
                
                '0'...'9' => {
                    if (char == '0' and self.matchOptionalString("x")) {
                        // hex
                        if (self.matchManyClass(charclass.hexDigit).len == 0) {
                            return self.emitInvalid("hex number literal missing digits", .{});
                        }
                        return self.emit(.number);

                    }
                    else {
                        // decimal
                        _ = self.matchManyClass(charclass.digit);
                        if (self.matchOptionalString(".")) {
                            if (self.matchManyClass(charclass.digit).len == 0) {
                                return self.emitInvalid("decimal number literal missing fractional digits", .{});
                            }
                        }
                        return self.emit(.number);
                    }
                },
                
                else => {
                    if (charclass.name(char) or char == '@') {
                        _ = self.matchManyClass(charclass.name);
                        if (char == '@') {
                            return self.emit(.builtin);
                        }
                        else {
                            inline for (Token.keywords) |keyword| {
                                if (std.mem.eql(u8, keyword, self.token.text)) {
                                    return self.emit(.keyword);
                                }
                            }
                            return self.emit(.name);
                        }
                    }
                    else {
                        if (std.ascii.isGraph(char)) {
                            return self.emitInvalid("invalid character", .{});
                        }
                        else {
                            return self.emitInvalid("invalid character byte '\\x{X}'", .{char});
                        }
                    }
                },
                
            }
        }
    }

    /// lex the rest of the file, logging any errors found
    pub fn rest(self: *Self) void {
        while (self.next()) |_| {}
    }

    pub const charclass = struct {
        
        pub fn valid(char: u8) bool {
            return std.ascii.isGraph(char) or char == ' ';
        }

        pub fn name(char: u8) bool {
            return switch (char) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => true,
                else => false,
            };
        }

        pub fn digit(char: u8) bool {
            return char >= '0' and char <= '9';
        }

        pub fn hexDigit(char: u8) bool {
            return switch (char) {
                '0'...'9', 'a'...'f', 'A'...'F', => true,
                else => false,
            };
        }

        pub fn lineEnd(char: u8) bool {
            return switch (char) {
                '\n', '\r' => true,
                else => false,
            };
        }

        pub fn notLineEnd(char: u8) bool {
            return valid(char) and !lineEnd(char);
        }


    };

    const CharClass = fn (u8) bool;

    fn matchManyClass(self: *Self, comptime char_class: CharClass) []const u8 {
        var len: usize = undefined;
        for (self.rest_text) |char, i| {
            len = i;
            if (!char_class(char)) {
                break;
            }
        }
        return self.read(len);
    }

    fn matchManyChar(self: *Self, comptime char: u8) []const u8 {
        return self.matchManyClass(struct {
            fn _(c: u8) bool {
                return c == char;
            }
        }._);
    }

    fn matchOptionalString(self: *Self, string: []const u8) bool {
        if (std.mem.eql(u8, string, self.peek(string.len))) {
            self.advance(string.len);
            return true;
        }
        else {
            return false;
        }
    }

    fn emit(self: *Self, comptime class: Token.Class) Token {
        var result = self.token;
        result.class = class;
        if (class == .line_end) {
            self.token.line.index += 1;
            self.token.line.start = @ptrToInt(self.rest_text.ptr) - @ptrToInt(self.source.text.ptr);
        }
        self.token.text = self.rest_text[0..0];
        var writer = std.io.getStdErr().writer();
        writer.writeAll(self.token.text) catch unreachable;
        return result;
    }

    fn emitInvalid(self: *Self, comptime fmt: []const u8, args: anytype) Token {
        if (self.log_errors) {
            log.logSourceToken(.err, self.token.sourceToken(), fmt, args) catch unreachable;
        }
        return self.emit(.invalid);
    }


};

const st = std.testing;

test {
    // const source = try Source.createFromBytes(st.allocator, "foo bar baz");
    const source = try Source.createFromFile(st.allocator, "sample/sample.umbra");
    defer source.destroy();
    var tokens = TokenStream.initFromSource(source);
    defer tokens.deinit();
    tokens.log_errors = false;
    const writer = std.io.getStdErr().writer();
    while (tokens.next()) |token| {
        try writer.print("{}", .{token});
    }
    try writer.writeByte('\n');
}