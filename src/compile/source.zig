const std = @import("std");
const util = @import("util");

usingnamespace @import("context.zig");
usingnamespace @import("unit.zig");

const Allocator = std.mem.Allocator;
const ZigSrcLoc = std.builtin.SourceLocation;

pub const Source = struct {

    allocator: *Allocator,

    path: []const u8,

    text: []const u8,

    lines: []const Line,

    pub const Line = SourceLine;
    pub const Token = SourceToken;

    const Self = @This();

    pub fn createFromFile(allocator: *Allocator, path: []const u8) !*const Self {
        var cwd = std.fs.cwd();
        var file = try cwd.openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();

        var text = try allocator.alloc(u8, file_size);
        errdefer allocator.free(text);

        _ = try file.readAll(text);

        return create(allocator, path, text);
    }

    fn create(allocator: *Allocator, path: []const u8, text: []const u8) !*const Self {
        var self = try allocator.create(Self);
        self.* = Self {
            .allocator = allocator,
            .path = path,
            .text = text,
            .lines = undefined,  
        };

        errdefer allocator.destroy(self);

        try self.initLines();

        return self;
    }

    pub fn destroy(self: *const Self) void {
        self.allocator.free(self.text);
        self.allocator.free(self.lines);
        self.allocator.destroy(self);
    }

    fn initLines(self: *Self) !void {
        var lines = std.ArrayList(Line).init(self.allocator);
        var lines_iter = std.mem.split(self.text, "\n");
        var index: usize = 0;
        while (lines_iter.next()) |line_text| {
            var line = Line {
                .source = self,
                .index = index,
                .text = line_text,
            };
            try lines.append(line);
            index += 1;
        }
        self.lines = lines.toOwnedSlice();
    }

    pub const FindTokenError = error {
        /// the given token is not a subslice of the source text
        NotTextSubSlice,
        /// the given token crosses a line boundary
        MultilineToken,
    };

    /// given a slice to a substring of this source file, find 
    pub fn findToken(self: *const Self, token_text: []const u8) FindTokenError!Token {
        for (token_text) |char| {
            // no multiline tokens
            if (char == '\n') {
                return FindTokenError.MultilineToken;
            }
        }
        if (!isSubSlice(self.text, token_text)) {
            return FindTokenError.NotTextSubSlice;
        }
        for (self.lines) |*line| {
            if (@ptrToInt(token_text.ptr) > @ptrToInt(line.text.ptr)) {
                const start = @ptrToInt(token_text.ptr) - @ptrToInt(line.text.ptr);
                return Token {
                    .line = line,
                    .start = start,
                    .len = token_text.len,
                };
            }
        }
        // if its not a multiline, and its in this source text,
        // we are garunteed to find it in one of the lines
        unreachable;
    }



};

fn isSubSlice(sup: []const u8, sub: []const u8) bool {
    const sub_start = @ptrToInt(sub.ptr);
    const sub_end = sub_start + sub.len * @sizeOf(u8);
    const sup_start = @ptrToInt(sup.ptr);
    const sup_end = sup_start + sup.len * @sizeOf(u8);
    return (
        sub_start >= sup_start and
        sub_start < sup_end and
        sub_end >= sup_start and
        sub_end <= sup_end
    );
}

const SourceLine = struct {

    source: *const Source,
    index: usize,
    text: []const u8,

    const Self = @This();

    pub fn token(self: *const Self, start: usize, len: usize) SourceToken {
        return SourceToken {
            .line = self,
            .start = start,
            .len = len,
        };
    }

    pub fn tokenFromSlice(self: *const Self, text: []const u8) SourceToken {
        if (std.debug.runtime_safety and !isSubSlice(self.text, text)) {
            std.debug.panic("token '{s}' out of bounds of line:\n'{s}'", .{text, self.text});
        }
        const start = @ptrToInt(text.ptr) - @ptrToInt(self.text.ptr);
        return self.token(start, text.len);
    }


};

const SourceToken = struct {

    line: *const SourceLine,
    start: usize,
    len: usize,

    const Self = @This();

    pub fn source(self: Self) *const Source {
        return self.line.source;
    }

    pub fn text(self: Self) []const u8 {
        return self.line.text[self.start..][0..self.len];
    }
    
    // pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    //     try writer.print("{s}:{d}\n")
    // }

};