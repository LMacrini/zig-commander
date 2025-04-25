const std = @import("std");
const Iterator = @import("./iterator.zig").Iterator;
const ArrayList = std.ArrayList;
const Types = std.builtin.Type;

inline fn toOptPtr(comptime T: type, val: ?T) ?*const T {
    return if (val) |v| &v else null;
}

pub const ParseError = std.fmt.ParseIntError || std.fmt.ParseFloatError || error {
};

const Param = struct {
    Type: type,
    default_value_ptr: ?*const anyopaque,
    parser: ?*const fn ([]const u8) ParseError!*const anyopaque,

    const Self = @This();

    pub inline fn defaultValue(self: Self) ?self.Type {
        const val: *const self.Type = @ptrCast(@alignCast(self.default_value_ptr orelse return null));
        return val.*;
    }

    pub fn parse(self: Self, string: []const u8) ParseError!self.Type {
        if (self.parser) |parser| {
            const func: self.ParserType() = @ptrCast(@alignCast(parser));
            return (try func(string)).*;

            // NOTE: another possible way of doing this, probably worse, likely to remove this comment
            // const res_ptr: *const self.Type = @ptrCast(@alignCast(try parser(string)));
            // return res_ptr.*;
        }

        if (self.Type == []const u8) {
            return string;
        }

        return switch (@typeInfo(self.Type)) {
            .int => std.fmt.parseInt(self.Type, string, 10),
            .bool => self.parseBool(string),
            else => @compileError("No parser provided"),
        };
    }

    fn ParserType(self: Self) type {
        return *const fn ([]const u8) ParseError!*const self.Type;
    }

    fn parseBool(self: Self, string: []const u8) !bool {
        if (string.len > 32) return self.defaultValue() orelse @panic("TODO: add more error handling");
        var buf: [32]u8 = undefined;
        const lower = std.ascii.lowerString(&buf, string);

        if (
            std.mem.eql(u8, lower, "yes")
            or std.mem.eql(u8, lower, "y")
            or std.mem.eql(u8, lower, "true")
            or std.mem.eql(u8, lower, "1")
        ) {
            return true;
        }
        
        if (
            std.mem.eql(u8, lower, "no")
            or std.mem.eql(u8, lower, "n")
            or std.mem.eql(u8, lower, "false")
            or std.mem.eql(u8, lower, "0")
        ) {
            return false;
        }

        return self.defaultValue() orelse @panic("TODO: add more error handling");
    }
};

fn OptionConfig(comptime T: type) type {
    return struct {
        short: ?u8 = null,
        description: []const u8 = "",
        parser: ?*const fn ([]const u8) ParseError!*const T = null,
    };
}

const Option = struct {
    name: [:0]const u8,
    short: ?u8,
    description: []const u8,
    param: Param,

    const Self = @This();

    pub fn defaultValue(self: Self) self.param.Type {
        return self.param.defaultValue();
    }

    pub fn parse(self: Self, string: []const u8) self.param.Type {
        return self.param.parse(string);
    }
};

fn ArgumentConfig(comptime T: type) type {
    return struct {
        description: []const u8 = "",
        default_value: ?T = null,
        parser: ?*const fn ([]const u8) ParseError!*const T = null,
    };
}

const Argument = struct {
    description: []const u8,
    param: Param,
};

const CommandOptions = struct {
    description: []const u8 = "",
};

pub const Command = struct {
    name: [:0]const u8,
    description: []const u8,
    options: []Option = &.{},
    commands: ?[]Command = null,
    arguments: ?[]Argument = null,

    const Self = @This();

    pub fn init(name: [:0]const u8, opts: CommandOptions) Self {
        return .{
            .name = name,
            .description = opts.description,
        };
    }

    pub fn addOption(self: *Self, comptime T: type, name: [:0]const u8, default_value: T, opts: OptionConfig(T)) *Self {
        const option = Option{
            .name = name,
            .short = opts.short,
            .description = opts.description,
            .param = .{
                .Type = T,
                .default_value_ptr = &default_value,
                .parser = @ptrCast(opts.parser),
            },
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
            .param = .{
                .Type = T,
                .default_value_ptr = toOptPtr(T, opts.default_value),
                .parser = @ptrCast(opts.parser),
            },
        };
        self.arguments = @constCast(self.arguments.? ++ .{argument});
        return self;
    }

    pub fn addCommand(self: *Self, command: Command) *Self {
        if (self.arguments != null) {
            @compileError("Cannot add subcommand if there are arguments");
        } else if (self.commands == null) {
            self.commands = &.{};
        }

        self.commands = @constCast(self.commands.? ++ .{command});
        return self;
    }

    pub fn parse(self: Self, allocator: std.mem.Allocator) !ParsedCommand(self) {
        return ParsedCommand(self).init(allocator);
    }
};

fn ParsedOptions(comptime opts: []const Option) type {
    var fields: [opts.len]Types.StructField = undefined;

    inline for (opts, 0..) |opt, i| {
        inline for (opts[0..i]) |other| {
            if (std.mem.eql(u8, opt.name, other.name)) @compileError("Cannot have options with duplicate names");
        }

        fields[i] = .{
            .name = opt.name,
            .type = opt.param.Type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(opt.param.Type),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

fn ParsedArguments(comptime args_or_null: ?[]const Argument) type {
    if (args_or_null == null) return void;

    const args = args_or_null.?;
    var fields: [args.len]Types.StructField = undefined;

    var has_default: bool = false;

    inline for (args, 0..) |arg, i| {
        if (has_default and arg.param.defaultValue() == null) {
            @compileError("Argument with default value cannot be followed by an argument without a default value");
        } else if (arg.param.defaultValue() != null) {
            has_default = true;
        }

        fields[i] = .{
            .name = std.fmt.comptimePrint("{}", .{i}),
            .type = arg.param.Type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(arg.param.Type),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = true,
        },
    });
}

fn ParsedCommands(comptime cmds_or_null: ?[]const Command) type {
    if (cmds_or_null == null) return void;
    
    const cmds = cmds_or_null.?;
    var tag_fields: [cmds.len]Types.EnumField = undefined;
    var fields: [cmds.len]Types.UnionField = undefined;

    inline for (cmds, 0..) |cmd, i| {
        inline for (cmds[0..i]) |other| {
            if (std.mem.eql(u8, cmd.name, other.name)) @compileError("Cannot have subcommands with duplicate names");
        }

        tag_fields[i] = .{
            .name = cmd.name,
            .value = i,
        };
        fields[i] = .{
            .name = cmd.name,
            .type = ParsedCommand(cmd),
            .alignment = @alignOf(ParsedCommand(cmd)),
        };
    }
    
    const TagSize = @Type(.{
        .int = .{
            .bits = std.math.log2_int_ceil(u16, cmds.len),
            .signedness = .unsigned,
        }
    });
    const Tag = @Type(.{
        .@"enum" = .{
            .tag_type = TagSize,
            .fields = &tag_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
    return @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = Tag,
            .fields = &fields,
            .decls = &.{},
        },
    });
}

const OptionNameType = union(enum) {
    short: u8,
    long: []const u8,
};

fn ParsedCommand(comptime cmd: Command) type {
    const Args = ParsedArguments(cmd.arguments);
    const Opts = ParsedOptions(cmd.options);
    const SubCmd = ParsedCommands(cmd.commands);

    return struct {
        allocator: std.mem.Allocator,
        args: Args,
        opts: Opts,
        subcommand: SubCmd,
        raw_args: []const [:0]u8,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !Self {
            const raw_args = try std.process.argsAlloc(allocator);
            errdefer std.process.argsFree(allocator, raw_args);

            return initWithSlice(allocator, raw_args);
        }

        fn initWithSlice(allocator: std.mem.Allocator, raw_args: []const [:0]u8) !Self {
            const has_args = cmd.arguments != null;
            const has_cmd = cmd.commands != null;

            var parsed_args: Args = undefined;
            var parsed_command: ?SubCmd = null;
            var parsed_opts: Opts = undefined;

            var positionals = ArrayList([]const u8).init(allocator);
            defer positionals.deinit();

            inline for (cmd.options) |option| {
                @field(parsed_opts, option.name) = option.param.defaultValue().?;
            }

            var args_iterator: Iterator([]u8) = .init(raw_args);
            _ = args_iterator.first();
            arg_loop: while (args_iterator.next()) |raw_arg| {
                if (has_args and !std.mem.startsWith(u8, raw_arg, "-")) {
                    try positionals.append(raw_arg);
                    continue;
                } else if (has_cmd and !std.mem.startsWith(u8, raw_arg, "-")) {
                    inline for (cmd.commands.?) |command| {
                        if (std.mem.eql(u8, command.name, raw_arg)) {
                            parsed_command = @unionInit(SubCmd, command.name, 
                                try .initWithSlice(allocator, raw_args[args_iterator.index.?..])
                            );
                            break :arg_loop;
                        }
                    }
                    return error.UnknownCommand;
                }

                if (!std.mem.startsWith(u8, raw_arg, "-")) return error.UnknownArgument;

                const option_name: OptionNameType = blk: {
                    if (raw_arg.len == 2 and raw_arg[1] != '-') {
                        break :blk .{ .short = raw_arg[1] };
                    }

                    if (raw_arg.len > 2 and raw_arg[1] == '-') {
                        break :blk .{ .long = raw_arg[2..] };
                    }

                    return error.UnknownArgument;
                };

                inline for (cmd.options) |option| continue_block: {
                    const is_match = switch (option_name) {
                        .short => |c| option.short != null and option.short.? == c,
                        .long => |name| std.mem.eql(u8, option.name, name),
                    };

                    if (is_match) {
                        if (args_iterator.next()) |next| {
                            @field(parsed_opts, option.name) = try option.param.parse(next);
                            break :continue_block;
                        }

                        return error.MissingOptionValue;
                    }
                }
            }

            if (has_args) {
                if (positionals.items.len < cmd.arguments.?.len) {
                    return error.NotEnoughArguments;
                }

                if (positionals.items.len > cmd.arguments.?.len) {
                    return error.TooManyArguments;
                }

                inline for (cmd.arguments.?, 0..) |argument, i| {
                    parsed_args[i] = try argument.param.parse(positionals.items[i]);
                }
            }

            return .{
                .allocator = allocator,
                .args = parsed_args,
                .opts = parsed_opts,
                .subcommand = if (has_cmd) parsed_command
                    orelse return error.MissingCommand,
                .raw_args = raw_args,
            };
        }

        pub fn deinit(self: *Self) void {
            std.process.argsFree(self.allocator, self.raw_args);
        }
    };
}
