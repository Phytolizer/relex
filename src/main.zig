const std = @import("std");
const Lexer = @import("Lexer.zig");

pub fn main() !void {
    var lexer = Lexer.new(@embedFile("example.relex"), .{ .filepath = "example.relex" });
    while (true) {
        const token = lexer.nextToken();
        std.debug.print("{}\n", .{token});
        if (token.kind == .eof) break;
    }
}
