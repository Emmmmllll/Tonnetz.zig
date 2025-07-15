const std = @import("std");
const notes = @import("notes.zig");
const Audio = @This();
const rl = @import("raylib");

fn raw_audio_callback(buf_ptr: ?*anyopaque, frames: c_uint) callconv(.c) void {
    const buf: [*]Audio.format = @alignCast(@ptrCast(buf_ptr));
    audio_callback(buf[0..frames]);
}
/// for the audio thread
var global_audio_ctx: Audio = undefined;

mutex: std.Thread.Mutex = .{},
sounds: std.EnumMap(notes.Key, Sound) = .{},
fade_duration: f32 = 200.0,
volume: f32 = 0.1,
stream: rl.AudioStream,

const sample_rate = 48000;
const buffer_size = sample_rate / 60;
const channels = 1;
const sample_size = @bitSizeOf(format);
const max_volume = if (@typeInfo(format) == .float) 1.0 else std.math.maxInt(format);
const format = f32;

pub const Sound = struct {
    frequency: f32,
    volume: f32 = 1.0,
    fade_phase: f32 = 0.0,
    phase: f32 = 0.0,
    waveform: Wave = .sine,
    fade: enum { max, fade_in, fade_out } = .fade_in,
};
pub const Wave = enum {
    sine,
    square,
    triangle,
    sawtooth,
};

inline fn audio_callback(buf: []Audio.format) void {
    global_audio_ctx.mutex.lock();
    defer global_audio_ctx.mutex.unlock();
    var sound_iter = global_audio_ctx.sounds.iterator();
    const n_sounds: f32 = @floatFromInt(global_audio_ctx.sounds.count());

    while (sound_iter.next()) |sound| {
        const incr = (sound.value.frequency / Audio.sample_rate) * std.math.tau;
        for (buf) |*sample| {
            const val: f32 =
                global_audio_ctx.volume *
                sound.value.fade_phase *
                (sound.value.volume / n_sounds) *
                Audio.max_volume *
                @as(f32, switch (sound.value.waveform) {
                    .sine => std.math.sin(sound.value.phase),
                    .square => if (sound.value.phase < std.math.pi) 1.0 else -1.0,
                    .triangle => sound.value.phase / std.math.tau,
                    .sawtooth => 2.0 * (sound.value.phase / std.math.tau) - 1.0,
                });
            if (@typeInfo(Audio.format) == .float) {
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
                    sound.value.fade_phase += 1000.0 / (Audio.sample_rate * global_audio_ctx.fade_duration);
                    if (sound.value.fade_phase >= 1.0) {
                        sound.value.fade = .max;
                        sound.value.fade_phase = 1.0;
                    }
                },
                .fade_out => {
                    sound.value.fade_phase -= 1000.0 / (Audio.sample_rate * global_audio_ctx.fade_duration);
                    if (sound.value.fade_phase <= 0.0) {
                        global_audio_ctx.sounds.remove(sound.key);
                    }
                },
                else => {},
            }
        }
    }
}

pub fn init() !*Audio {
    const audio_stream = try rl.loadAudioStream(sample_rate, buffer_size, channels);
    global_audio_ctx = Audio{
        .stream = audio_stream,
    };
    rl.setAudioStreamCallback(audio_stream, &raw_audio_callback);
    rl.playAudioStream(audio_stream);
    return &global_audio_ctx;
}
pub fn deinit(self: *Audio) void {
    self.mutex.lock();
    rl.unloadAudioStream(self.stream);
}

pub fn lock(self: *Audio) void {
    self.mutex.lock();
}

pub fn unlock(self: *Audio) void {
    self.mutex.unlock();
}

pub fn pauseStream(self: *Audio) void {
    rl.pauseAudioStream(self.stream);
}

pub fn resumeStream(self: *Audio) void {
    rl.playAudioStream(self.stream);
}

pub fn addOrModifySound(self: *Audio, note: notes.Key, new_sound: Sound) ?*Sound {
    if (self.sounds.getPtr(note)) |sound| {
        return sound;
    } else {
        self.sounds.put(note, new_sound);
        return null;
    }
}

pub fn modifySound(self: *Audio, note: notes.Key) ?*Sound {
    return self.sounds.getPtr(note);
}

pub fn removeSound(self: *Audio, note: notes.Key) void {
    if (self.sounds.getPtr(note)) |sound| {
        sound.fade = .fade_out;
    }
}
