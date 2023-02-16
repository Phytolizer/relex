const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        a: std.mem.Allocator,
        alloc: []T,
        begin: usize = 0,
        end: usize = 0,
        items: []T,

        const Self = @This();

        pub fn init(a: std.mem.Allocator) Self {
            return .{
                .a = a,
                .alloc = &.{},
                .items = &.{},
            };
        }

        pub fn deinit(self: Self) void {
            self.a.free(self.alloc);
        }

        fn updateItems(self: *Self) void {
            self.items = self.alloc[self.begin..self.end];
        }

        fn resize(self: *Self) !void {
            const new_cap = if (self.alloc.len == 0) 8 else self.alloc.len * 2;
            const new_mem = try self.a.alloc(T, new_cap);
            std.mem.copy(T, new_mem, self.items);
            self.begin = 0;
            self.end = self.items.len;
            self.updateItems();
            self.a.free(self.alloc);
            self.alloc = new_mem;
        }

        pub fn enqueue(self: *Self, item: T) !void {
            if (self.items.len + self.begin == self.alloc.len) {
                try self.resize();
            }

            self.items[self.items.len] = item;
            self.end += 1;
            self.updateItems();
        }

        pub fn dequeue(self: *Self) !T {
            if (self.items.len == 0) {
                return error.QueueEmpty;
            }

            const item = self.items[0];
            self.begin += 1;
            self.updateItems();
            return item;
        }
    };
}
