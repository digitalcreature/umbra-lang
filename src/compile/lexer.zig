const std = @import("std");

usingnamespace @import("source.zig");
usingnamespace @import("context.zig");
usingnamespace @import("unit.zig");
usingnamespace @import("token.zig");
usingnamespace @import("log.zig");

const Allocator = std.mem.Allocator;


pub const Lexer = struct {

    allocator: *Allocator,

    unit: *Unit,
    source: *const Source,

    error_count: usize = 0,
    line: *const Source.Line,
    line_text: []const u8 = "",

    const Self = @This();

    pub fn create(unit: *Unit) !*Self {
        const self = try unit.allocator.create(Self);
        self.* = Self {
            .allocator = unit.allocator,
            .unit = unit,
            .source = unit.source,
            .line = undefined,
        };
        return self;
    }

    pub fn destroy(self: *Self) void {
        self.allocator.destroy(self);
    }

    const TokenList = std.ArrayList(Token);

    /// attempt to lex the source file
    /// returns null if there were any errors
    pub fn lex(self: *Self) !?TokenStream {
        var tokens = TokenList.init(self.allocator);
        errdefer tokens.deinit();
        for (self.source.lines) |*line| {
            self.line = line;
            // trim comment
            var comment_splitter = std.mem.split(line.text, "`");
            self.line_text = comment_splitter.next().?;
            _ = try self.lexLine(&tokens);
        }
        if (self.error_count > 0) {
            tokens.deinit();
            return null;
        }
        else {
            try tokens.append(Token.initLineSeperator(.eof, self.line));
            return TokenStream.init(self.unit, tokens.toOwnedSlice());
        }
    }

    fn lexLine(self: *Self, tokens: *TokenList) !void {
        self.skipWhitespace();
        while (self.line_text.len > 0) {
            if (self.lexToken()) |token| {
                try tokens.append(token);
            }
            else {
                return;
            }
            self.skipWhitespace();
        }
        try tokens.append(Token.initLineSeperator(.eol, self.line));
    }

    /// assume `line_text.len > 0`, and the next character is not a space
    /// returns null on error, after logging it.
    fn lexToken(self: *Self) ?Token {
        const first_char = self.line_text[0];
        if (char_classes.punctuation(first_char)) {
            return self.expectEnumeratedToken(.punctuation);
        }
        else if (char_classes.operator(first_char)) {
            return self.expectEnumeratedToken(.operator);
        }
        else if (first_char == '@') {
            return self.expectEnumeratedToken(.builtin);
        }
        else if (char_classes.identStart(first_char)) {
            var token_text = self.readTokenCharacters(char_classes.ident);
            if (Token.matchClass(.keyword, token_text, self.line)) |keyword_token| {
                return keyword_token;
            }
            else {
                return Token.initValue(.ident, token_text, self.line);
            }
        }
        else if (char_classes.digit(first_char)) {
            return Token.initValue(
                .number,
                self.readNumberLiteral(),
                self.line,
            );
        }
        else {
            self.log(.err, self.line_text[0..1], "unexpected character '{c}'", .{first_char});
            return null;
        }
    }

    fn log(self: *Self, comptime level: Log.Level, token_text: []const u8, comptime fmt: []const u8, args: anytype) void {
        if (level == .err) {
            self.error_count += 1;
        }
        const source_token = self.line.tokenFromSlice(token_text);
        self.unit.context.log.logSourceToken(level, source_token, fmt, args) catch |err| { @panic(@errorName(err)); };
    }

    const char_classes = struct {

        fn space(char: u8) bool {
            return switch (char) {
                ' ', '\t', '\r' => true,
                else => false,
            };
        }

        fn punctuation(char: u8) bool {
            return switch (char) {
                '(', ')', '[', ']', '{', '}',
                '.', ':', ',', ';' => true,
                else => false,
            };
        }

        fn operator(char: u8) bool {
            return switch (char) {
                '+', '-', '*', '/', '%', '=',
                '~', '|', '&', '>', '<' => true,
                else => false,
            };
        }

        fn builtin(char: u8) bool {
            return switch(char) {
                'a'...'z', 'A'...'Z' => true,
                else => false,
            };
        }

        fn identStart(char: u8) bool {
            return switch(char) {
                'a'...'z', 'A'...'Z', '_' => true,
                else => false,
            };
        }

        fn ident(char: u8) bool {
            return switch(char) {
                'a'...'z', 'A'...'Z',
                '0'...'9', '_' => true,
                else => false,
            };
        }

        fn digit(char: u8) bool {
            return char >= '0' and char <= '9';
        }

        fn forTokenClass(comptime class: Token.Class) CharClass {
            return comptime switch (class) {
                .punctuation => punctuation,
                .operator => operator,
                .builtin => builtin,
                else => @compileError("no simple character class for token class '" ++ @tagName(class) ++ "'"),
            };
        }

    };

    fn expectEnumeratedToken(self: *Self, comptime class: Token.Class) ?Token {
        const token_text = (
            if (class == .punctuation) (
                // punctuation tokens are all one character long
                self.readNCharacters(1)
            )
            else (
                self.readTokenCharacters(comptime char_classes.forTokenClass(class))
            )
        );
        if (Token.matchClass(class, token_text, self.line)) |token| {
            return token;
        }
        else {
            self.log(.err, token_text, "invalid {s} '{s}'", .{@tagName(class), token_text});
            return null;
        }
    }

    const CharClass = fn(u8) bool;

    fn skipWhitespace(self: *Self) void {
        const isSpace = char_classes.space;
        const line_text = self.line_text;
        if (line_text.len > 0 and isSpace(line_text[0])) {
            _ = self.readTokenCharacters(isSpace);
        }
    }

    fn readNumberLiteral(self: *Self) []const u8 {
        const isDigit = char_classes.digit;
        var token_text = self.readTokenCharacters(isDigit);
        const line_text = self.line_text;
        if (line_text.len > 0 and line_text[0] == '.') {
            if (line_text.len == 1 or !isDigit(line_text[1])) {     
                _ = self.readNCharacters(1);
                token_text.len += 1;
                return token_text;
            }
            else {
                const frac_text = self.readTokenCharacters(isDigit);
                token_text.len += frac_text.len;
                return token_text;
            }
        }
        else {
            return token_text;
        }
    }

    /// reads characters matching `char_class` and advances `self.line_text`
    /// NOTE: does not check the first character! only use where you know the first
    /// character is valid
    fn readTokenCharacters(self: *Self, comptime char_class: CharClass) []const u8 {
        var line_text = self.line_text;
        var i: usize = 1;   // skip the first character, we already know its valid
        const len = (
            while (i < line_text.len) : (i += 1) {
                if (!char_class(line_text[i])) {
                    break i;
                }
            }
            else (line_text.len)
        );
        return self.readNCharacters(len);
    }

    /// assume `line_text.len >= len`
    fn readNCharacters(self: *Self, len: usize) []const u8 {
        var line_text = self.line_text;
        const read_characters = line_text[0..len];
        if (len == line_text.len) {
            line_text.len = 0;
        }
        else {
            line_text = line_text[len..];
        }
        self.line_text = line_text;
        return read_characters;
    }

};


const ansi = @import("util").ansi;

pub const TokenStream = struct {

    unit: *Unit,
    tokens: []const Token,

    const Self = @This();

    pub fn init(unit: *Unit, tokens: []const Token) Self {
        return Self {
            .unit = unit,
            .tokens = tokens,
        };
    }

    pub fn deinit(self: Self) void {
        self.unit.allocator.free(self.tokens);
    }


    pub fn dump(self: Self, writer: anytype) !void {
        try writer.print("{s}", .{self.unit.source.path});
        var last_token: *const Token = undefined;
        for (self.tokens) |*token, i| {
            if (i == 0 or last_token.line.index != token.line.index) {
                // first token on the line
                const line = token.line;
                const source_token = token.sourceToken();
                const indent_slice = line.text[0..source_token.start];
                try writer.print("\n{d: >3}: {s}", .{(line.index + 1) % 1000, indent_slice});
            }
            try writer.print("{} ", .{token});
            last_token = token;
        }
        try writer.writeByte('\n');
    }

};

const ttt = @import("testing.zig");

const Zsl = std.builtin.SourceLocation;

fn createTestingLexerFile(path: []const u8) !*Lexer {
    const unit = try ttt.createTestingUnitFromFile(path);
    errdefer unit.context.destroy();
    return Lexer.create(unit);
}

fn destroyTestingLexer(lexer: *Lexer) void {
    lexer.unit.context.destroy();
    lexer.destroy();
}

fn lexAndDumpFile(path: []const u8) !void {
    std.testing.log_level = .debug;
    var stderr = std.io.getStdErr().writer();
    try stderr.writeByte('\n');
    try stderr.writeByte('\n');
    const lexer = try createTestingLexerFile(path);
    defer destroyTestingLexer(lexer);
    if (try lexer.lex()) |stream| {
        try stream.dump(stderr);
        stream.deinit();
        try stderr.writeByte('\n');
    }

}

test {
    try lexAndDumpFile("sample/let.umbra");
}