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

    const res = try cmd.parse(std.heap.page_allocator);

    std.debug.print("{any}\n", .{res});
}

const std = @import("std");
const lib = @import("commander_lib");
