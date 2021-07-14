const std = @import("std");

usingnamespace @import("source.zig");
usingnamespace @import("context.zig");

const Allocator = std.mem.Allocator;

pub const Unit = struct {

    allocator: *Allocator,

    context: *Context,
    
    source: Source.Ptr,

    const Self = @This();

    pub fn create(context: *Context, source: Source.Ptr) !*Self {
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
};