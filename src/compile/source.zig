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

    pub const Ptr = *const Self;
    pub const Line = SourceLine;
    pub const Token = SourceToken;

    const Self = @This();

    pub fn createFromFile(allocator: *Allocator, path: []const u8) !Ptr {
        var cwd = std.fs.cwd();
        var file = try cwd.openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();

        var text = try allocator.alloc(u8, file_size);
        errdefer allocator.free(text);

        _ = try file.readAll(text);

        return create(allocator, path, text);
    }

    pub fn createFromBytes(allocator: *Allocator, bytes: []const u8) !Ptr {
        const text = try allocator.dupe(u8, bytes);
        errdefer allocator.free(text);
        return try create(allocator, "(string)", text);
    }

    fn create(allocator: *Allocator, path: []const u8, text: []const u8) !Ptr {
        var self = try allocator.create(Self);
        self.* = Self {
            .allocator = allocator,
            .path = path,
            .text = text,
        };

        // errdefer allocator.destroy(self);

        // try self.initLines();

        return self;
    }

    pub fn destroy(self: Ptr) void {
        self.allocator.free(self.text);
        self.allocator.destroy(self);
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

    source: Source.Ptr,
    index: usize,
    start: usize,

    pub const Ptr = *const Self;
    
    const Self = @This();

    pub fn init(source: Source.Ptr, index: usize, start: usize) Self {
        return Self {
            .source = source,
            .index = index,
            .start = start,
        };
    }

    pub fn token(self: Self, start: usize, len: usize) SourceToken {
        return SourceToken {
            .line = self,
            .start = start,
            .len = len,
        };
    }

    pub fn text(self: Self) []const u8 {
        var st = self.source.text[self.start..];
        for (st) |char, i| {
            switch (char) {
                '\n' => return st[0..i],
                '\r' => {
                    if ((i+1 < st.len) and st[i+i] == '\n') {
                        return st[0..i];
                    }
                },
                else => {}
            }
        }
        return st;
    }

    pub fn tokenFromSlice(self: Self, slice: []const u8) SourceToken {
        if (std.debug.runtime_safety) {
            const self_text = self.text();
            if (!isSubSlice(self_text, slice)) {
                std.debug.panic("token '{s}' out of bounds of line:\n'{s}'", .{slice, self_text});
            }
        }
        const token_start = @ptrToInt(slice.ptr) - @ptrToInt(self.source.text.ptr);
        return self.token(token_start - self.start, slice.len);
    }


};

const SourceToken = struct {

    line: Source.Line,
    start: usize,
    len: usize,

    const Self = @This();

    pub fn source(self: Self) Source.Ptr {
        return self.line.source;
    }

    pub fn text(self: Self) []const u8 {
        return self.line.text()[self.start..][0..self.len];
    }
    
    // pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    //     try writer.print("{s}:{d}\n")
    // }

};