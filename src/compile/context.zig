const std = @import("std");

usingnamespace @import("source.zig");
usingnamespace @import("unit.zig");
usingnamespace @import("log.zig");

const Allocator = std.mem.Allocator;

pub const Context = struct {

    allocator: *Allocator,
    units: UnitList,
    log: Log,

    const UnitList = std.ArrayList(*Unit);

    const Self = @This();

    pub fn create(allocator: *Allocator) !*Self {
        const self = try allocator.create(Self);

        self.* = Self {
            .allocator = allocator,
            .units = UnitList.init(allocator),
            .log = Log{},
        };

        return self;
    }

    pub fn destroy(self: *Self) void {
        for (self.units.items) |unit| {
            unit.destroy();
        }
        self.units.deinit();
        self.allocator.destroy(self);
    }


    pub fn addUnitFromFile(self: *Self, path: []const u8) !*Unit {
        const source = try Source.createFromFile(self.allocator, path);
        errdefer source.destroy();
        return self.addUnit(source);
    }

    // pub fn addUnitFromEmbed(self: *Self, comptime zig_src_loc: std.builtin.SourceLocation, text: []const u8) !*Unit {
    //     const source = try Source.initFromEmbed(self.allocator, zig_src_loc, text);
    //     errdefer source.deinit();
    //     return self.addUnit(source);
    // }

    fn addUnit(self: *Self, source: *const Source) !*Unit {
        const unit = try Unit.create(self, source);
        errdefer unit.destroy();
        try self.units.append(unit);
        return unit;
    }

};