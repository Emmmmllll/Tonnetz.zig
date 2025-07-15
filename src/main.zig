const rl = @import("raylib");
const std = @import("std");
const notes = @import("notes.zig");
const TonnetzGrid = @import("TonnetzGrid.zig");
const Audio = @import("Audio.zig");

comptime {
    _ = TonnetzGrid;
}

pub fn main() !void {
    const dimensions = .{
        .w = 800,
        .h = 450,
    };

    rl.initWindow(dimensions.w, dimensions.h, "test window");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const audio = try Audio.init();
    defer audio.deinit();
    var current_wave: Audio.Wave = .sine;

    rl.setTargetFPS(60);

    var last_click: i64 = 0;
    var last_clicked: ?notes.Key = null;
    const double_click_delay: i64 = 500;

    var grid = TonnetzGrid.init(.{
        .color_map = .init(.{
            .c = .red,
            .db = .orange,
            .d = .yellow,
            .eb = .green,
            .e = .blue,
            .f = .purple,
            .@"f#_gb" = .pink,
            .g = .brown,
            .ab = .gray,
            .a = .black,
            .bb = .white,
            .b = rl.Color.init(0xFF, 0xA5, 0x00, 0xFF), // orange
        }),
    });
    var key_map = [_]struct { kb: rl.KeyboardKey, note: notes.Key, state: enum { off, kb, toggle } = .off }{
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
    };

    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(.w)) {
            current_wave = switch (current_wave) {
                .sine => .square,
                .square => .triangle,
                .triangle => .sawtooth,
                .sawtooth => .sine,
            };
        }

        for (&key_map) |*key_pair| {
            if (key_pair.state == .toggle) continue;
            const is_down = rl.isKeyDown(key_pair.kb);
            const has_changed = (key_pair.state == .kb) != is_down;
            key_pair.state = if (is_down) .kb else .off;
            if (has_changed) {
                audio.lock();
                defer audio.unlock();
                if (is_down) {
                    if (audio.addOrModifySound(key_pair.note, .{
                        .waveform = current_wave,
                        .frequency = key_pair.note.to_frequency(0),
                    })) |sound| {
                        sound.fade = .fade_in;
                    }
                } else audio.removeSound(key_pair.note);
            }
        }

        if (rl.isMouseButtonPressed(.left)) blk: {
            const now = std.time.milliTimestamp();
            const click_delay = now - last_click;
            last_click = now;

            const mouse_pos = rl.getMousePosition();
            const item = grid.clickedItem(mouse_pos) orelse {
                last_clicked = null;
                break :blk;
            };
            if (click_delay < double_click_delay and last_clicked != null and last_clicked.? == item.key) {
                audio.mutex.lock();
                defer audio.mutex.unlock();
                const is_pressed = item.is_pressed;
                item.is_pressed = !is_pressed;

                if (!is_pressed) {
                    if (audio.addOrModifySound(item.key, .{
                        .frequency = item.key.to_frequency(item.octave),
                        .waveform = current_wave,
                    })) |sound| {
                        sound.fade = .fade_in;
                        sound.frequency = item.key.to_frequency(item.octave);
                        sound.waveform = current_wave;
                    }
                    key_map[@intFromEnum(item.key)].state = .toggle;
                } else {
                    audio.removeSound(item.key);
                    key_map[@intFromEnum(item.key)].state = .off;
                }
                last_clicked = null;
            } else last_clicked = item.key;
        }
        if (rl.isMouseButtonPressed(.right)) blk: {
            const mouse_pos = rl.getMousePosition();
            const item = grid.clickedItem(mouse_pos) orelse break :blk;
            audio.lock();
            defer audio.unlock();
            if (item.octave < 3) item.octave += 1 else item.octave = -2;
            if (audio.modifySound(item.key)) |sound| {
                sound.frequency = item.key.to_frequency(item.octave);
                sound.waveform = current_wave;
            }
        }

        for (&grid.keys) |*item| {
            item.is_pressed = key_map[@intFromEnum(item.key)].state != .off;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        grid.draw();
        draw_current_wave(current_wave);
        draw_volume(audio.volume);
        // break;
    }
}

fn draw_current_wave(current_wave: Audio.Wave) void {
    var text_buf: [64]u8 = undefined;
    const text = std.fmt.bufPrintZ(&text_buf, "Current wave: {s}", .{@tagName(current_wave)}) catch @panic("Unexpected: Format failed");
    rl.drawText(text, 4, 4, 16, .black);
}

fn draw_volume(volume: f32) void {
    var text_buf: [64]u8 = undefined;
    const intvolume: u8 = @intFromFloat(volume * 100.0);
    const text = std.fmt.bufPrintZ(&text_buf, "Volume: {}", .{intvolume}) catch @panic("Unexpected: Format failed");
    rl.drawText(text, 4, 24, 16, .black);
}
