const std = @import("std");
const notes = @import("notes.zig");
const Grid = @This();
const rl = @import("raylib");

const Key = notes.Key;

const Style = struct {
    gaps: struct { u32, u32 } = .{ 50, 50 },
    radius: f32 = 20,
    line_width: u32 = 2,
    color_map: std.EnumArray(notes.Key, rl.Color) = .initFill(.yellow),
};

const Item = packed struct(u16) {
    key: Key,
    octave: i3,
    is_pressed: bool,
    pos: packed struct(u8) { x: PosNum, y: PosNum },

    const PosNum = u4;
    const max_pos = std.math.maxInt(PosNum);
    const num_pos = max_pos + 1;

    pub fn coords(self: Item, style: *const Style) struct { u32, u32 } {
        const h_gap, const v_gap = style.gaps;
        const iradius: u32 = @intFromFloat(style.radius);
        const x: u32 = @intCast(self.pos.x * (h_gap + iradius));
        const y: u32 = @intCast(self.pos.y * (v_gap + iradius) + if (self.pos.x % 2 == 1) (iradius + v_gap) / 2 else 0);
        return .{ x, y };
    }
};

keys: [Item.num_pos * Item.num_pos]Item,
style: Style,

pub fn init(style: Style) Grid {
    var self: Grid = .{
        .style = style,
        .keys = undefined,
    };
    var key = Key.c;
    for (&self.keys, 0..) |*item, idx| {
        item.* = Item{
            .key = key,
            .octave = 0,
            .is_pressed = false,
            .pos = .{ .x = @intCast(idx / Item.num_pos), .y = @intCast(idx % Item.num_pos) },
        };
        key = if (idx % Item.num_pos != Item.max_pos)
            key.backward(.perfect_fifth)
        else if (item.pos.x % 2 == 0)
            key.backward(.diminished_fifth)
        else
            key.forward(.minor_second);
    }
    return self;
}

pub fn idxFromPos(x: u4, y: u4) usize {
    const big_x: usize = @intCast(x);
    const big_y: usize = @intCast(y);
    return (big_y + big_x * Item.num_pos);
}

pub fn clickedItem(self: *Grid, mouse_pos: rl.Vector2) ?*Item {
    const style = self.style;
    for (&self.keys) |*item| {
        const x, const y = item.coords(&style);
        if (rl.checkCollisionPointCircle(mouse_pos, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, style.radius)) {
            return item;
        }
    }
    return null;
}

pub fn draw(self: *const Grid) void {
    for (self.keys) |item| self.draw_area(item);
    for (self.keys) |item| self.draw_connections(item);
    for (self.keys) |item| self.draw_circle(item);
}

fn draw_connections(self: *const Grid, circle: Item) void {
    const style = self.style;
    // const iradius: u32 = @intFromFloat(style.radius);
    const max = Item.max_pos;
    const offsets = [_]struct { u4, i4 }{
        .{ 0, 1 },
        .{ 1, 0 },
        .{ 1, if (circle.pos.x % 2 == 0) -1 else 1 },
    };
    const sx, const sy = circle.coords(&style);
    for (offsets) |offset| {
        const ox, const oy = offset;
        const pos = circle.pos;
        if (pos.x == max and ox == 1) continue;
        if (pos.y == max and oy == 1) continue;
        if (pos.y == 0 and oy == -1) continue;
        const neighbour = self.keys[idxFromPos(pos.x + ox, @intCast(@as(i32, @intCast(pos.y)) + oy))];
        const ex, const ey = neighbour.coords(&style);
        rl.drawLine(
            @intCast(sx),
            @intCast(sy),
            @intCast(ex),
            @intCast(ey),
            .black,
        );
    }
}

fn draw_area(self: *const Grid, circle: Item) void {
    if (!circle.is_pressed) return;
    const style = self.style;
    const pos = circle.pos;
    if (pos.x == Item.max_pos) return;
    // shared_offset
    const shared_offset_x, const shared_offset_y = [_]u4{ 1, if (pos.x % 2 == 0) 0 else 1 };
    if (pos.y == Item.max_pos and shared_offset_y == 1) return;
    const shared_circle = self.keys[idxFromPos(pos.x + shared_offset_x, pos.y + shared_offset_y)];
    if (!shared_circle.is_pressed) return;
    const sx, const sy = circle.coords(&self.style);
    const scx, const scy = shared_circle.coords(&self.style);
    const offsets = [_]struct { u4, i4 }{
        .{ 0, 1 },
        .{ 1, if (pos.x % 2 == 0) -1 else 0 },
    };
    for (offsets) |offset| {
        const ox, const oy = offset;
        if (pos.y == Item.max_pos and oy == 1) continue;
        if (pos.y == 0 and oy == -1) continue;
        const corner = self.keys[idxFromPos(pos.x + ox, @intCast(@as(i32, @intCast(pos.y)) + oy))];
        if (!corner.is_pressed) continue;
        const ex, const ey = corner.coords(&self.style);

        const start_col = style.color_map.get(circle.key);
        const shared_col = style.color_map.get(shared_circle.key);
        const end_col = style.color_map.get(corner.key);

        const CVec = @Vector(4, usize);

        var color_vec = CVec{
            @intCast(start_col.r),
            @intCast(start_col.g),
            @intCast(start_col.b),
            @intCast(start_col.a),
        };

        color_vec += CVec{
            @intCast(shared_col.r),
            @intCast(shared_col.g),
            @intCast(shared_col.b),
            @intCast(shared_col.a),
        };

        color_vec += CVec{
            @intCast(end_col.r),
            @intCast(end_col.g),
            @intCast(end_col.b),
            @intCast(end_col.a),
        };

        const v2, const v3 = if (offset[0] == 0) .{
            rl.Vector2{ .x = @floatFromInt(ex), .y = @floatFromInt(ey) },
            rl.Vector2{ .x = @floatFromInt(scx), .y = @floatFromInt(scy) },
        } else .{
            rl.Vector2{ .x = @floatFromInt(scx), .y = @floatFromInt(scy) },
            rl.Vector2{ .x = @floatFromInt(ex), .y = @floatFromInt(ey) },
        };

        const colr, const colg, const colb, const cola = color_vec / @as(CVec, @splat(3));
        rl.drawTriangle(
            .{ .x = @floatFromInt(sx), .y = @floatFromInt(sy) },
            v2,
            v3,
            .{
                .r = @intCast(colr),
                .g = @intCast(colg),
                .b = @intCast(colb),
                .a = @intCast(cola),
            },
            // .pink,
        );
    }
}

fn draw_circle(self: *const Grid, circle: Item) void {
    const style = self.style;
    const iradius: u32 = @intFromFloat(style.radius);
    const x, const y = circle.coords(&style);
    rl.drawCircle(
        @intCast(x),
        @intCast(y),
        style.radius,
        if (circle.is_pressed) style.color_map.get(circle.key) else .light_gray,
    );
    var text_buf: [8]u8 = undefined;
    const text = std.fmt.bufPrintZ(&text_buf, "{s} {}", .{ @tagName(circle.key), circle.octave }) catch @panic("Unexpected: Format failed");
    const font_size: u32 = iradius / 2;
    const text_w: u32 = @intCast(rl.measureText(text, @intCast(font_size)));
    rl.drawText(
        text,
        @intCast(x -| (text_w / 2)),
        @intCast(y -| (font_size / 2)),
        @intCast(font_size),
        .black,
    );
}
