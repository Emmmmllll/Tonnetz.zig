const rl = @import("raylib");
const std = @import("std");
const notes = @import("notes.zig");
const TonnetzGrid = @import("TonnetzGrid.zig");

comptime {
    _ = TonnetzGrid;
}

fn raw_audio_callback(buf_ptr: ?*anyopaque, frames: c_uint) callconv(.c) void {
    const buf: [*]AudioCtx.format = @alignCast(@ptrCast(buf_ptr));
    audio_callback(buf[0..frames]);
}

const AudioCtx = struct {
    const Sound = struct {
        frequency: f32,
        volume: f32,
        fade_phase: f32 = 0.0,
        phase: f32 = 0.0,
        waveform: Wave = .sine,
        fade: enum { max, fade_in, fade_out } = .fade_in,
    };
    const Wave = enum {
        sine,
        square,
        triangle,
        sawtooth,
    };
    mutex: std.Thread.Mutex = .{},
    sounds: std.EnumMap(notes.Key, Sound) = .{},
    fade_duration: f32 = 200.0,

    const sample_rate = 48000;
    const buffer_size = sample_rate / 60;
    const channels = 1;
    const sample_size = @bitSizeOf(format);
    const max_volume = if (@typeInfo(format) == .float) 1.0 else std.math.maxInt(format);
    const format = f32;
};
var global_audio_ctx: *AudioCtx = undefined;

inline fn audio_callback(buf: []AudioCtx.format) void {
    global_audio_ctx.mutex.lock();
    defer global_audio_ctx.mutex.unlock();
    var sound_iter = global_audio_ctx.sounds.iterator();
    const n_sounds: f32 = @floatFromInt(global_audio_ctx.sounds.count());

    while (sound_iter.next()) |sound| {
        const incr = (sound.value.frequency / AudioCtx.sample_rate) * std.math.tau;
        for (buf) |*sample| {
            const val: f32 = sound.value.fade_phase * (sound.value.volume / n_sounds) * AudioCtx.max_volume * @as(f32, switch (sound.value.waveform) {
                .sine => std.math.sin(sound.value.phase),
                .square => if (sound.value.phase < std.math.pi) 1.0 else -1.0,
                .triangle => sound.value.phase / std.math.tau,
                .sawtooth => 2.0 * (sound.value.phase / std.math.tau) - 1.0,
            });
            if (@typeInfo(AudioCtx.format) == .float) {
                sample.* += @floatCast(val);
            } else {
                sample.* = @intFromFloat(val);
            }
            sound.value.phase += incr;
            if (sound.value.phase >= std.math.tau) {
                sound.value.phase -= std.math.tau;
            }
            switch (sound.value.fade) {
                .fade_in => {
                    sound.value.fade_phase += 1000.0 / (AudioCtx.sample_rate * global_audio_ctx.fade_duration);
                    if (sound.value.fade_phase >= 1.0) {
                        sound.value.fade = .max;
                        sound.value.fade_phase = 1.0;
                    }
                },
                .fade_out => {
                    sound.value.fade_phase -= 1000.0 / (AudioCtx.sample_rate * global_audio_ctx.fade_duration);
                    if (sound.value.fade_phase <= 0.0) {
                        global_audio_ctx.sounds.remove(sound.key);
                    }
                },
                else => {},
            }
        }
    }
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

    var audio_ctx = AudioCtx{};
    var current_wave: AudioCtx.Wave = .sine;
    global_audio_ctx = &audio_ctx;

    const audio_stream = try rl.loadAudioStream(AudioCtx.sample_rate, AudioCtx.sample_size, AudioCtx.channels);
    defer rl.unloadAudioStream(audio_stream);

    rl.setAudioStreamCallback(audio_stream, &raw_audio_callback);
    // rl.setAudioStreamBufferSizeDefault(AudioCtx.buffer_size);
    rl.playAudioStream(audio_stream);

    rl.setTargetFPS(60);

    // var rng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));

    var last_click: i64 = 0;
    var last_ckicked: ?notes.Key = null;
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
                audio_ctx.mutex.lock();
                defer audio_ctx.mutex.unlock();
                if (audio_ctx.sounds.getPtr(key_pair.note)) |sound| {
                    if (is_down)
                        sound.fade = .fade_in
                    else
                        sound.fade = .fade_out;
                } else if (is_down) {
                    audio_ctx.sounds.put(key_pair.note, .{
                        .volume = 0.1,
                        .waveform = current_wave,
                        .frequency = key_pair.note.to_frequency(0),
                    });
                }
            }
        }

        if (rl.isMouseButtonPressed(.left)) blk: {
            const now = std.time.milliTimestamp();
            const click_delay = now - last_click;
            last_click = now;

            const mouse_pos = rl.getMousePosition();
            const item = grid.clickedItem(mouse_pos) orelse {
                last_ckicked = null;
                break :blk;
            };
            if (click_delay < double_click_delay and last_ckicked != null and last_ckicked.? == item.key) {
                audio_ctx.mutex.lock();
                defer audio_ctx.mutex.unlock();
                const is_pressed = item.is_pressed;
                item.is_pressed = !is_pressed;
                if (audio_ctx.sounds.getPtr(item.key)) |sound| {
                    if (is_pressed)
                        sound.fade = .fade_out
                    else {
                        sound.fade = .fade_in;
                        sound.frequency = item.key.to_frequency(item.octave);
                        sound.waveform = current_wave;
                    }
                } else if (!is_pressed) {
                    audio_ctx.sounds.put(item.key, .{
                        .frequency = item.key.to_frequency(item.octave),
                        .volume = 0.1,
                        .waveform = current_wave,
                    });
                }
                if (is_pressed) {
                    key_map[@intFromEnum(item.key)].state = .off;
                } else {
                    key_map[@intFromEnum(item.key)].state = .toggle;
                }
                last_ckicked = null;
            } else last_ckicked = item.key;
        }
        if (rl.isMouseButtonPressed(.right)) blk: {
            const mouse_pos = rl.getMousePosition();
            const item = grid.clickedItem(mouse_pos) orelse break :blk;
            audio_ctx.mutex.lock();
            defer audio_ctx.mutex.unlock();
            if (item.octave < 3) item.octave += 1 else item.octave = -2;
            if (audio_ctx.sounds.getPtr(item.key)) |sound| {
                sound.frequency = item.key.to_frequency(item.octave);
                sound.waveform = current_wave;
            } else {
                audio_ctx.sounds.put(item.key, .{
                    .frequency = item.key.to_frequency(item.octave),
                    .volume = 0.1,
                    .waveform = current_wave,
                });
            }
        }

        for (&grid.keys) |*item| {
            item.is_pressed = key_map[@intFromEnum(item.key)].state != .off;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        grid.draw();
        var text_buf: [64]u8 = undefined;
        const text = std.fmt.bufPrintZ(&text_buf, "Current wave: {s}", .{@tagName(current_wave)}) catch @panic("Unexpected: Format failed");
        rl.drawText(text, 4, 4, 16, .black);
        // break;
    }
}
