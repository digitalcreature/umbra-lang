const std = @import("std");

usingnamespace @import("source.zig");

/// the max possible length of hashables
/// theres a weird zig bug, so im sticking with u64 for now.
/// this means keywords are limited to 7 characters in length, and builtins are matched by tag name
const string_hash_bytes = 7;
pub const StringHash = std.meta.Int(.unsigned, (string_hash_bytes + 1) * 8);

pub const Token = struct {

    name: Name,
    value: []const u8,
    line: *const Source.Line,

    pub const Class = TokenClass;
    pub const Name = TokenName;

    const Self = @This();

    /// attempt to match a token to a given token class
    /// calling using the `value` or `line_sep` token classes is a compile error,
    /// use `Token.initValue()` or `Token.initLineSeperator()` instead
    pub fn matchClass(comptime class: Class, text: []const u8, line: *const Source.Line) ?Self {
        comptime {
            if (class == .value) {
                @compileError(
                    "cannot use Token.match() for the value token class."
                    ++ "use Token.initValue instead"
                );
            }
        }
        if (class == .builtin and (text[0] != '@' or text.len <= 1)) {
            return null;
        }
        const text_hash = hash(text, class);
        inline for (comptime std.enums.values(Name)) |name| {
            if (comptime name.class() == class) {
                if (class == .builtin) {
                    const builtin_name = @tagName(name)[3..];   // remove the "at_" prefix
                    if (std.mem.eql(u8, builtin_name, text[1..])) {
                        return Self {
                            .name = name,
                            .value = text,
                            .line = line,
                        };
                    }
                }
                else if (text_hash == name.hash()) {
                    return Self {
                        .name = name,
                        .value = text,
                        .line = line,
                    };
                }
            }
        }
        return null;
    }


    /// initialize a new value token.
    /// using a token name that is not in the `value` token class is a compile error,
    /// use `Token.matchClass()` or `Token.initLineSeperator()` instead
    pub fn initValue(comptime name: Name, value: []const u8, line: *const Source.Line) Self {
        comptime {
            if (!name.isValue()) {
                @compileError(
                    "cannot init Token with non-value name '" ++ @tagName(name) ++ "'."
                    ++ " use Token.matchClass() or Token.initLineSeperator() instead."
                );
            }
        }
        return Self {
            .name = name,
            .value = value,
            .line = line,
        };
    }

    /// initialize a new line_sep token.
    /// using a token name that is not in the `whitepace` token class is a compile error,
    /// use `Token.matchClass()` or `Token.initValue()` instead
    pub fn initLineSeperator(comptime name: Name, line: *const Source.Line) Self {
        comptime {
            if (!name.isLineSeperator()) {
                @compileError(
                    "cannot init Token with non-line_sep name '" ++ @tagName(name) ++ "'."
                    ++ " use Token.matchClass() or Token.initValue() instead."
                );
            }
        }
        return Self {
            .name = name,
            .value = "",    // line_sep tokens dont have any meaningful text value
            .line = line,
        };
    }

    pub fn sourceToken(self: *const Self) Source.Token {
        if (self.name.isLineSeperator()) {
            return self.line.token(0, 0);
        }
        else {
            return self.line.tokenFromSlice(self.value);
        }
    }

    fn hash(string: []const u8, comptime class: Class) ?StringHash {
        if (string.len > string_hash_bytes) {
            return null;
        }
        else {
            var result: StringHash = 0;
            for (string) |char, i| {
                result <<= 8;
                result |= char;
            }
            // result <<= 8;
            // result |= @truncate(u8, string.len);
            result <<= 8;
            result |= @enumToInt(class);
            return result;
        }
    }

    
    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const name = self.name;
        if (name.isValue()) {
            try writer.print("\"{s}\"", .{self.value});
        }
        else if (name.isLineSeperator()) {
            try writer.print("<{s}>", .{ @tagName(name)});
        }
        else {
            try writer.print("`{s}`", .{ self.value});
        }
    }

};

const TokenName = enum(StringHash) {
    paren_open = punctuation("("),
    paren_close = punctuation(")"),
    square_open = punctuation("["),
    square_close = punctuation("]"),
    curly_open = punctuation("{"),
    curly_close = punctuation("}"),
    dot = punctuation("."),
    colon = punctuation(":"),
    semicolon = punctuation(";"),
    comma = punctuation(","),

    plus = operator("+"),
    minus = operator("-"),
    aster = operator("*"),
    slash = operator("/"),
    percent = operator("%"),
    equal = operator("="),
    tilde = operator("~"),
    pipe = operator("|"),
    amp = operator("&"),
    shift_left = operator("<<"),
    shift_right = operator(">>"),

    kw_let = keyword("let"),
    // kw_vert = keyword("vert"),
    // kw_inst = keyword("inst"),
    // kw_param = keyword("param"),
    
    at_transform = builtin(0),
    at_affine = builtin(1),
    at_pos = builtin(2),
    at_dir = builtin(3),
    at_mix = builtin(4),
    at_interp = builtin(5),

    ident = value(0),
    number = value(1),

    eol = lineSep(0),
    eof = lineSep(1),


    fn punctuation(text: []const u8) StringHash {
        return Token.hash(text, .punctuation).?;
    }

    fn operator(text: []const u8) StringHash {
        return Token.hash(text, .operator).?;
    }

    fn keyword(text: []const u8) StringHash {
        return Token.hash(text, .keyword).?;
    }

    fn unhashed(index: u8, token_class: Token.Class) StringHash {
        return (@as(StringHash, index) << 8) | @enumToInt(token_class);
    }

    fn builtin(index: u8) StringHash {
        return unhashed(index, .builtin);
    }

    fn value(index: u8) StringHash {
        return unhashed(index, .value);
    }

    fn lineSep(index: u8) StringHash {
        return unhashed(index, .line_sep);
    }

    const Self = @This();

    pub fn class(self: Self) Token.Class {
        return @intToEnum(Token.Class, @truncate(u8, self.hash() & 0xff));
    }

    pub fn isEnumerated(self: Self) bool {
        return self.class().isEnumerated();
    }

    pub fn isValue(self: Self) bool {
        return self.class().isValue();
    }

    pub fn isLineSeperator(self: Self) bool {
        return self.class().isLineSeperator();
    }

    pub fn hash(self: Self) StringHash {
        return @enumToInt(self);
    }

};

const TokenClass = enum(u8) {
    punctuation,
    operator,
    keyword,
    builtin,
    value,
    line_sep,

    const Self = @This();

    pub fn isEnumerated(self: Self) bool {
        return !self.isValue() and !self.isLineSeperator();
    }

    pub fn isValue(self: Self) bool {
        return self == .value;
    }

    pub fn isLineSeperator(self: Self) bool {
        return self == .line_sep;
    }
};