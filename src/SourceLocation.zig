const std = @import("std");

/// Path to the file where the token is located.
filepath: []const u8,
/// 1-based line number.
line: usize = 1,
/// 1-based column number.
column: usize = 1,
/// 0-based byte offset.
offset: usize = 0,

pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("{s}:{d}:{d}", .{ self.filepath, self.line, self.column });
}
