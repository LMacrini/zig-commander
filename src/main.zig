//! This file is just an example

const Operations = enum {
    add,
    sub,
};

const math_cmd = blk: {
    var new_cmd = lib.Command.init("math", .{});

    _ = new_cmd
        .addArgument(Operations, .{
            .description = "do an operation",
        })
        .addArgument(isize, .{})
        .addArgument(isize, .{});

    break :blk new_cmd;
};

const main_cmd = blk: {
    var new_cmd = lib.Command.init("main", .{});

    const help_cmd = lib.Command.init("help", .{
        .description = "prints the help",
    });

    _ = new_cmd
        .addCommand(help_cmd)
        .addCommand(math_cmd);

    break :blk new_cmd;
};

fn math(cmd: math_cmd.ParsedType()) !void {
    const stdout = std.io.getStdOut().writer();

    const a = cmd.args[1];
    const b = cmd.args[2];

    const res = switch (cmd.args[0]) {
        .add => a + b,
        .sub => a - b,
    };

    try stdout.print("{d}\n", .{res});
}

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.detectLeaks();
    };

    const allocator = debug_allocator.allocator();

    var res = main_cmd.parse(allocator) catch |err| {
        std.log.err("{s}", .{@errorName(err)});
        std.process.exit(1);
    };
    defer res.deinit();

    switch (res.subcommand) {
        .help => std.log.info("this is the help", .{}),
        .math => |cmd| try math(cmd),
    }
}

const std = @import("std");
const builtin = @import("builtin");
const lib = @import("commander_lib");
