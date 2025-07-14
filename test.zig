const std = @import("std");

export fn hey() void {
    std.debug.print("Hey from build.zig!\n", .{});
}
