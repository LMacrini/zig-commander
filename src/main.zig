//! This file is just an example

fn parseBool(_: []const u8) !*bool {
    var b = false;
    return &b;
}

const silly = blk: {
    var new_cmd = lib.Command.init("silly", .{
        .description = "is silly",
    });

    _ = new_cmd.addArgument(u8, .{});

    break :blk new_cmd;
};

const cmd = blk: {
    var new_cmd = lib.Command.init("main", .{});

    _ = new_cmd.addOption(u8, "ball", 8, .{})
        .addOption(bool, "enable", true, .{
            .short = 'e',
            .description = "enables the switch",
            .parser = &parseBool,
        })
        .addCommand(silly);

    break :blk new_cmd;
};

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.detectLeaks();
    };

    const allocator = debug_allocator.allocator();

    var res = cmd.parse(allocator) catch |err| {
        std.log.err("{s}", .{@errorName(err)});
        std.process.exit(1);
    };
    defer res.deinit();

    std.debug.print("{any}\n", .{res.subcommand.silly.args[0]});
}

const std = @import("std");
const builtin = @import("builtin");
const lib = @import("commander_lib");
