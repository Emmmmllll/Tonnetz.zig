const Self = @This();
const rl = @import("raylib");
const std = @import("std");
const util = @import("util.zig");
const Pos = util.Pos;

text: [:0]const u8,
pos: Pos,
color: rl.Color = .black,
font: ?rl.Font = null,
fontsize: f32 = 20.0,

const Options = struct {
    strategy: union(enum) {
        buf: []u8,
        alloc: std.mem.Allocator,
    },
    pos: Pos,
    color: rl.Color = .black,
    font: ?rl.Font = null,
    fontsize: f32 = 20.0,
};
pub fn initFmt(comptime fmt: []const u8, args: anytype, opts: Options) !Self {
    var self = Self{
        .text = "",
        .pos = opts.pos,
        .color = opts.color,
        .font = opts.font,
        .fontsize = opts.fontsize,
    };
    switch (opts.strategy) {
        .buf => |buf| try self.setFmtBufText(buf, fmt, args),
        .alloc => |allocator| try self.setFmtAllocText(allocator, fmt, args),
    }
    return self;
}
/// Only call if the text was allocated.
/// Else it will likely crash the program.
pub fn free(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.text);
}

pub fn setFmtBufText(self: *Self, buf: []u8, comptime fmt: []const u8, args: anytype) !void {
    self.text = try std.fmt.bufPrintZ(buf, fmt, args);
}

pub fn setFmtAllocText(
    self: *Self,
    allocator: std.mem.Allocator,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    self.text = try std.fmt.allocPrintZ(allocator, fmt, args);
}

pub fn draw(self: *const Self) void {
    if (self.font) |font| {
        rl.drawTextEx(font, self.text, self.pos.toVec2(), self.fontsize, 2.0, self.color);
    } else {
        rl.drawText(self.text, @intFromFloat(self.pos.x), @intFromFloat(self.pos.y), @intFromFloat(self.fontsize), self.color);
    }
}

pub fn drawFmt(
    comptime fmt: []const u8,
    args: anytype,
    opts: Options,
) !void {
    var label = try Self.initFmt(fmt, args, opts);
    defer if (opts.strategy == .alloc) label.free(opts.strategy.alloc);
    label.draw();
}

pub fn measureSize(self: *const Self) Pos {
    if (self.font) |font| {
        return Pos.fromVec2(rl.measureTextEx(font, self.text, self.fontsize, 2.0));
    } else {
        return Pos.fromVals(
            rl.measureText(self.text, @intFromFloat(self.fontsize)),
            self.fontsize,
        );
    }
}

pub fn includesPos(self: *const Self, point: Pos) bool {
    const size = self.measureSize();
    return point.x >= self.pos.x and point.x <= self.pos.x + size.x and
        point.y >= self.pos.y and point.y <= self.pos.y + size.y;
}
