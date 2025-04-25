const std = @import("std");
const testing = std.testing;

pub fn Iterator(comptime T: type) type {
    return struct {
        buffer: []const T,
        index: ?usize = null,

        const Self = @This();

        pub fn init(buffer: []const T) Self {
            return .{
                .buffer = buffer,
            };
        }

        pub fn first(self: *Self) ?T {
            if (self.buffer.len == 0) return null;
            
            if (self.index == null) {
                self.index = 0;
            }

            return self.buffer[self.index.?];
        }

        /// only use if the iterator hasn't started yet
        pub fn current(self: Self) T {
            return self.buffer[self.index.?];
        }

        pub fn next(self: *Self) ?T {
            if (self.peek()) |next_value| {
                self.index = if (self.index) |idx| idx + 1 else 0;
                return next_value;
            }
            return null;
        }

        pub fn peek(self: *Self) ?T {
            if (self.buffer.len == 0) return null;

            const index = if (self.index) |idx| idx + 1 else 0;
            if (index == self.buffer.len) {
                return null;
            }
            return self.buffer[index];
        }

        pub fn reset(self: *Self) void {
            self.index = null;
        }
    };
}

test "iterator" {
    const string = "hello";
    var list = std.ArrayList(u8).init(testing.allocator);
    defer list.deinit();
    
    var i: usize = 0;
    var iterator = Iterator(u8).init(string);
    while (iterator.next()) |char| : (i+=1) {
        try list.append(char);
        try list.writer().print("{d}", .{i});
    }

    try testing.expectEqualSlices(u8, list.items, "h0e1l2l3o4");
}
