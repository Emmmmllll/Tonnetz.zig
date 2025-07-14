const std = @import("std");

pub const Key = enum(u4) {
    c,
    db,
    d,
    eb,
    e,
    f,
    @"f#_gb",
    g,
    ab,
    a,
    bb,
    b,

    pub const max: comptime_int = @intCast(@intFromEnum(Key.b));

    fn text(self: Key) [:0]const u8 {
        return switch (self) {
            .c => "C",
            .db => "Db",
            .d => "D",
            .eb => "Eb",
            .e => "E",
            .f => "F",
            .@"f#_gb" => "F#",
            .g => "G",
            .ab => "Ab",
            .a => "A",
            .bb => "Bb",
            .b => "B",
        };
    }

    fn as_int(self: Key) u4 {
        return @intFromEnum(self);
    }

    fn from_int(value: u4) Key {
        return @enumFromInt(value);
    }

    fn switch_fith_idx(val: u4) u4 {
        if (val % 2 == 0) return @intCast(val);
        if (val < Key.@"f#_gb".as_int()) return @intCast(val + 6);
        return @intCast(val - 6);
    }

    pub fn forward(self: Key, step: Step) Key {
        const int_val: usize = @intCast(self.as_int());
        return from_int(@intCast(((int_val + step.val) % (max + 1))));
    }

    pub fn backward(self: Key, step: Step) Key {
        const int_val: isize = @intCast(self.as_int());
        const istep: isize = @intCast(step.val);
        return from_int(@intCast(@mod(int_val - istep, max + 1)));
    }

    pub fn less_than(self: Key, other: Key) bool {
        return self.as_int() < other.as_int();
    }

    pub fn to_frequency(self: Key, octave: i32) f32 {
        const base_a4: f32 = 440.0;
        return base_a4 * std.math.pow(f32, 2.0, @as(f32, @floatFromInt(@intFromEnum(self) + 12 * octave - 9)) / 12.0); // - 57
    }
};

pub const Step = packed struct(u8) {
    val: u8,
    pub fn from_int(value: u8) Step {
        return Step{ .val = value };
    }
    pub const prime = from_int(0);
    pub const minor_second = from_int(1);
    pub const major_second = from_int(2);
    pub const minor_third = from_int(3);
    pub const major_third = from_int(4);
    pub const perfect_fourth = from_int(5);
    pub const augmented_fourth = from_int(6);
    pub const diminished_fifth = from_int(6);
    pub const perfect_fifth = from_int(7);
    pub const minor_sixth = from_int(8);
    pub const major_sixth = from_int(9);
    pub const minor_seventh = from_int(10);
    pub const major_seventh = from_int(11);
    pub const octave = from_int(12);
    pub const minor_ninth = from_int(13);
    pub const major_ninth = from_int(14);
    pub const minor_tenth = from_int(15);
    pub const major_tenth = from_int(16);
    pub const minor_eleventh = from_int(17);
    pub const major_eleventh = from_int(18);
    pub const minor_thirteenth = from_int(19);
    pub const major_thirteenth = from_int(20);
    pub const perfect_fourteenth = from_int(21);
    pub const augmented_fourteenth = from_int(22);
    pub const diminished_seventeenth = from_int(22);
    pub const perfect_seventeenth = from_int(23);
};
