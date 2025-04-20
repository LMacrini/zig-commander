//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const ArrayList = std.ArrayList;
const testing = std.testing;

fn OptionConfig(comptime T: type) type {
    return struct {
        short: ?u8 = null,
        description: []const u8 = "",
        default_value: ?T = null,
    };
}

const Option = struct {
    name: []const u8,
    short: ?u8,
    description: []const u8,
    Type: type,
    default_value_ptr: ?*const anyopaque,

    const Self = @This();

    pub inline fn defaultValue(comptime self: Self) ?self.Type {
        const val: *const self.Type = @ptrCast(@alignCast(self.default_value_ptr orelse return null));
        return val.*;
    }
};

fn ArgumentConfig(comptime T: type) type {
    _ = T;
    return struct {
        description: []const u8 = "",
    };
}

const Argument = struct {
    description: []const u8,
    Type: type,
};

const CommandOptions = struct {
    description: []const u8 = "",
};

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    options: []Option = &.{},
    commands: ?[]Command = null,
    arguments: ?[]Argument = null,

    const Self = @This();

    pub fn init(name: []const u8, opts: CommandOptions) Self {
        return .{
            .name = name,
            .description = opts.description,
        };
    }

    pub fn deinit(self: *Self) void {
        self.options.deinit();
    }

    pub fn addOption(self: *Self, comptime T: type, name: []const u8, opts: OptionConfig(T)) *Self {
        const option = Option{
            .name = name,
            .short = opts.short,
            .description = opts.description,
            .Type = T,
            .default_value_ptr = if (opts.default_value) |v| &v else null,
        };
        self.options = @constCast(self.options ++ .{option});
        return self;
    }

    pub fn addArgument(self: *Self, comptime T: type, opts: ArgumentConfig(T)) *Self {
        if (self.commands != null) {
            @compileError("Cannot add argument if there are subcommands");
        } else if (self.arguments == null) {
            self.arguments = &.{};
        }

        const argument = Argument{
            .description = opts.description,
            .Type = T,
        };
        self.arguments = @constCast(self.arguments.? ++ .{argument});
        return self;
    }

    pub fn addCommand(self: *Self) *Self {
        if (self.arguments != null) {
            @compileError("Cannot add subcommand if there are arguments");
        } else if (self.commands == null) {
            self.commands = &.{};
        }
    }
};

const TestStruct = struct {
    type: type,
    val: u8 = 1,

    pub fn nothing(self: *TestStruct, n: self.type) *TestStruct {
        self.val +|= @truncate(n);
        return self;
    }
};

test "newoption" {
    const allocator = testing.allocator;

    comptime var cool: TestStruct = .{ .type = usize };

    _ = cool.nothing(1)
        .nothing(3);


    std.debug.print("{}\n", .{ cool });

    _ = allocator;
}
