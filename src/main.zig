const rl = @import("raylib");
const std = @import("std");
const notes = @import("notes.zig");
const TonnetzGrid = @import("TonnetzGrid.zig");
const Audio = @import("Audio.zig");
const App = @import("App.zig");

comptime {
    _ = TonnetzGrid;
}

pub fn main() !void {
    const dimensions = .{
        .w = 800,
        .h = 450,
    };

    rl.initWindow(dimensions.w, dimensions.h, "Tonnetz");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();
    rl.setTargetFPS(60);

    var app = App{
        .grid = TonnetzGrid.init(.{
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
        }),
        .audio = try Audio.init(),
        .current_wave = .sine,
    };
    defer app.deinit();

    while (!rl.windowShouldClose()) {
        app.handleInput();
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);
        app.draw();
    }
}
