const std = @import("std");

usingnamespace @import("source.zig");
usingnamespace @import("context.zig");
usingnamespace @import("lexer.zig");

const Allocator = std.mem.Allocator;

pub const Unit = struct {

    allocator: *Allocator,

    context: *Context,
    
    source: *const Source,
    token_stream: ?TokenStream = null,

    const Self = @This();

    pub fn create(context: *Context, source: *const Source) !*Self {
        const allocator = context.allocator;
        var self = try allocator.create(Self);
        self.* = Self {
            .allocator = allocator,
            .context = context,
            .source = source,
        };
        return self;
    }

    pub fn destroy(self: *Self) void {
        self.source.destroy();
        if (self.token_stream) |token_stream| {
            token_stream.deinit();
        }
        self.allocator.destroy(self);
    }
    
    // pub fn lex(self: *Self) !bool {
    //     const lexer = try Lexer.create(self);
    //     if (try lexer.lex()) |token_stream| {
    //         self.token_stream = token_stream;
    //         return true;
    //     }
    //     else {
    //         return false;
    //     }
    // }

};