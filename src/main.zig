const std = @import("std");
const Parser = @import("Parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    var parser = Parser.init(
        @embedFile("example.relex"),
        a,
        .{ .filepath = "example.relex" },
    );
    defer parser.deinit();
}
