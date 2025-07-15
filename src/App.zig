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
state: State = .{},

const State = struct {
    curr_wave_text_buf: [64]u8 = undefined,
    volume_text_buf: [64]u8 = undefined,
    curr_wave_label: Label = .{ .text = "Hi", .pos = .fromVals(4, 4), .fontsize = 16 },
    volume_label: Label = .{ .text = "Test", .pos = .fromVals(4, 24), .fontsize = 16 },
};

pub fn deinit(self: *App) void {
    self.audio.deinit();
}

pub fn handleInput(self: *App) void {
    const audio = self.audio;
    if (rl.isKeyPressed(.w)) {
        self.current_wave = next_wave(self.current_wave);
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
        const last_clicked = self.last_clicked;
        self.last_clicked = null;

        const mouse_pos = rl.getMousePosition();
        if (self.state.curr_wave_label.includesPos(.fromVec2(mouse_pos))) {
            audio.lock();
            defer audio.unlock();
            self.current_wave = next_wave(self.current_wave);
            break :blk;
        }
        const item = self.grid.clickedItem(mouse_pos) orelse break :blk;
        if (click_delay < self.double_click_delay and last_clicked != null and last_clicked.? == item.key) {
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
}

pub fn draw(self: *App) void {
    self.grid.draw();
    self.state.curr_wave_label.draw();
    self.state.volume_label.draw();
}

pub fn update_state(self: *App) !void {
    const state = &self.state;
    state.curr_wave_label.setFmtBufText(
        &state.curr_wave_text_buf,
        "Current wave: {s}",
        .{@tagName(self.current_wave)},
    ) catch unreachable;
    state.volume_label.setFmtBufText(
        &state.volume_text_buf,
        "Volume: {}",
        .{@as(u8, @intFromFloat(self.audio.volume * 100.0))},
    ) catch unreachable;
    for (&self.grid.keys) |*item| {
        item.is_pressed = self.key_map[@intFromEnum(item.key)].state != .off;
    }
}

fn next_wave(wave: Audio.Wave) Audio.Wave {
    return switch (wave) {
        .sine => .square,
        .square => .triangle,
        .triangle => .sawtooth,
        .sawtooth => .sine,
    };
}
