const std = @import("std");
const rl = @import("raylib");
const notes = @import("notes.zig");
const TonnetzGrid = @import("TonnetzGrid.zig");
const Audio = @import("Audio.zig");
const Label = @import("ui/Label.zig");

const App = @This();

last_click: i64 = 0,
last_clicked: ?notes.Key = null,
double_click_delay: i64 = 300,
grid: TonnetzGrid,
key_map: [notes.Key.max + 1]struct { kb: rl.KeyboardKey, note: notes.Key, state: enum { off, kb, toggle } = .off } = .{
    .{ .kb = .z, .note = .c },
    .{ .kb = .s, .note = .db },
    .{ .kb = .x, .note = .d },
    .{ .kb = .d, .note = .eb },
    .{ .kb = .c, .note = .e },
    .{ .kb = .v, .note = .f },
    .{ .kb = .g, .note = .@"f#_gb" },
    .{ .kb = .b, .note = .g },
    .{ .kb = .h, .note = .ab },
    .{ .kb = .n, .note = .a },
    .{ .kb = .j, .note = .bb },
    .{ .kb = .m, .note = .b },
},
audio: *Audio,
current_wave: Audio.Wave = .sine,

pub fn deinit(self: *App) void {
    self.audio.deinit();
}

pub fn handleInput(self: *App) void {
    const audio = self.audio;
    if (rl.isKeyPressed(.w)) {
        self.current_wave = switch (self.current_wave) {
            .sine => .square,
            .square => .triangle,
            .triangle => .sawtooth,
            .sawtooth => .sine,
        };
    }

    for (&self.key_map) |*key_pair| {
        if (key_pair.state == .toggle) continue;
        const is_down = rl.isKeyDown(key_pair.kb);
        const has_changed = (key_pair.state == .kb) != is_down;
        key_pair.state = if (is_down) .kb else .off;
        if (has_changed) {
            audio.lock();
            defer audio.unlock();
            if (is_down) {
                if (audio.addOrModifySound(key_pair.note, .{
                    .waveform = self.current_wave,
                    .frequency = key_pair.note.to_frequency(0),
                })) |sound| {
                    sound.fade = .fade_in;
                }
            } else audio.removeSound(key_pair.note);
        }
    }

    if (rl.isMouseButtonPressed(.left)) blk: {
        const now = std.time.milliTimestamp();
        const click_delay = now - self.last_click;
        self.last_click = now;

        const mouse_pos = rl.getMousePosition();
        const item = self.grid.clickedItem(mouse_pos) orelse {
            self.last_clicked = null;
            break :blk;
        };
        if (click_delay < self.double_click_delay and self.last_clicked != null and self.last_clicked.? == item.key) {
            audio.mutex.lock();
            defer audio.mutex.unlock();
            const is_pressed = item.is_pressed;
            item.is_pressed = !is_pressed;

            if (!is_pressed) {
                if (audio.addOrModifySound(item.key, .{
                    .frequency = item.key.to_frequency(item.octave),
                    .waveform = self.current_wave,
                })) |sound| {
                    sound.fade = .fade_in;
                    sound.frequency = item.key.to_frequency(item.octave);
                    sound.waveform = self.current_wave;
                }
                self.key_map[@intFromEnum(item.key)].state = .toggle;
            } else {
                audio.removeSound(item.key);
                self.key_map[@intFromEnum(item.key)].state = .off;
            }
            self.last_clicked = null;
        } else self.last_clicked = item.key;
    }
    if (rl.isMouseButtonPressed(.right)) blk: {
        const mouse_pos = rl.getMousePosition();
        const item = self.grid.clickedItem(mouse_pos) orelse break :blk;
        audio.lock();
        defer audio.unlock();
        if (item.octave < 3) item.octave += 1 else item.octave = -2;
        if (audio.modifySound(item.key)) |sound| {
            sound.frequency = item.key.to_frequency(item.octave);
            sound.waveform = self.current_wave;
        }
    }

    for (&self.grid.keys) |*item| {
        item.is_pressed = self.key_map[@intFromEnum(item.key)].state != .off;
    }
}

pub fn draw(self: *App) void {
    self.grid.draw();
    draw_current_wave(self.current_wave);
    draw_volume(self.audio.volume);
}

fn draw_current_wave(current_wave: Audio.Wave) void {
    var text_buf: [64]u8 = undefined;
    Label.drawFmt("Current wave: {s}", .{@tagName(current_wave)}, .{
        .strategy = .{ .buf = &text_buf },
        .pos = .fromVals(4, 4),
        .fontsize = 16,
    }) catch unreachable;
}

fn draw_volume(volume: f32) void {
    var text_buf: [64]u8 = undefined;
    const intvolume: u8 = @intFromFloat(volume * 100.0);
    Label.drawFmt("Volume: {}", .{intvolume}, .{
        .strategy = .{ .buf = &text_buf },
        .pos = .fromVals(4, 24),
        .fontsize = 16,
    }) catch unreachable;
}
