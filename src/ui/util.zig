const std = @import("std");
const rl = @import("raylib");

fn cast_to(comptime T: type, value: anytype) T {
    if (comptime @TypeOf(value) == T) return value;
    return switch (@typeInfo(T)) {
        .int => switch (@typeInfo(@TypeOf(value))) {
            .int => @intCast(value),
            .comptime_int => value,
            .float, .comptime_float => @intFromFloat(value),
            else => @compileError("Unsupported value type"),
        },
        .float => switch (@typeInfo(@TypeOf(value))) {
            .int, .comptime_int => @floatFromInt(value),
            .float => @floatCast(value),
            .comptime_float => value,
            else => @compileError("Unsupported value type"),
        },
        else => @compileError("Unsupported target type"),
    };
}

pub const Pos = struct {
    x: f32,
    y: f32,

    pub fn fromVec2(vec: rl.Vector2) Pos {
        return Pos{ .x = vec.x, .y = vec.y };
    }
    pub fn fromVals(x: anytype, y: anytype) Pos {
        return Pos{
            .x = cast_to(f32, x),
            .y = cast_to(f32, y),
        };
    }
    pub fn toVec2(self: *const Pos) rl.Vector2 {
        return rl.Vector2.init(self.x, self.y);
    }
};
