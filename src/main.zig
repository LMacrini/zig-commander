//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

pub fn main() !void {
    comptime var cmd = lib.Command.init("main", .{});

    _ = cmd.addOption(u8, "ball", .{})
        .addOption(bool, "enable", .{
            .short = 'e',
            .default_value = true,
            .description = "enables the switch"
        });

    inline for (cmd.options) |option| {
        std.debug.print("option: {any} ", .{option});
        if (option.defaultValue()) |v| {
            std.debug.print("default value: {any}", .{v});
        }
        std.debug.print("\n", .{});
    }
}

const std = @import("std");
const lib = @import("commander_lib");
