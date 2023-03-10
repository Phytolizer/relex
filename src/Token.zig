const std = @import("std");
const SourceLocation = @import("SourceLocation.zig");

kind: Kind,
loc: SourceLocation,
text: []const u8,

/// Many tokens are only contextually valid.
/// However, the lexer does no validation; only the parser does.
pub const Kind = enum {
    @"error",
    eof,
    whitespace,
    left_brace,
    right_brace,
    left_bracket,
    right_bracket,
    left_paren,
    right_paren,
    semicolon,
    equal,
    pipe,
    dash,
    star,
    plus,
    question,
    comma,
    caret,
    dot,
    /// could be escaped with backslash
    literal_char,
    percent_percent,

    /// macro name, but could also be a literal_char
    identifier,

    // Keywords
    kw_alias,
    kw_tokens,
};

pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("{}: {s}: {s}", .{
        self.loc,
        std.meta.tagName(self.kind),
        self.text,
    });
}
