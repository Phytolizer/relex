const std = @import("std");
const SourceLocation = @import("SourceLocation.zig");
const Token = @import("Token.zig");

source: []const u8,
loc: SourceLocation,
token_start: usize = 0,

pub const Options = struct {
    filepath: ?[]const u8 = null,
};

pub fn new(source: []const u8, options: Options) @This() {
    return .{
        .source = source,
        .loc = .{
            .filepath = options.filepath orelse "<input>",
        },
    };
}

fn peekChar(self: @This()) ?u8 {
    if (self.loc.offset >= self.source.len) return null;
    return self.source[self.loc.offset];
}

fn nextChar(self: *@This()) ?u8 {
    const ch = self.peekChar() orelse return null;
    self.loc.column += 1;
    self.loc.offset += 1;
    if (ch == '\n') {
        self.loc.line += 1;
        self.loc.column = 1;
    }
    return ch;
}

fn tokenText(self: @This()) []const u8 {
    return self.source[self.token_start..self.loc.offset];
}

fn lexWhitespace(self: *@This(), was_comment: bool) void {
    var in_comment = was_comment;
    while (self.peekChar()) |ch| {
        switch (ch) {
            ' ', '\t', '\r' => _ = self.nextChar(),
            '\n' => {
                in_comment = false;
                _ = self.nextChar();
            },
            '#' => {
                in_comment = true;
                _ = self.nextChar();
            },
            else => {
                if (in_comment)
                    _ = self.nextChar()
                else
                    break;
            },
        }
    }
}

fn lexIdentifier(self: *@This()) Token.Kind {
    while (true) {
        const ch = self.peekChar() orelse break;
        switch (ch) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => _ = self.nextChar(),
            else => break,
        }
    }

    const text = self.tokenText();
    const keywords = std.ComptimeStringMap(Token.Kind, .{
        .{ "alias", .kw_alias },
        .{ "tokens", .kw_tokens },
    });

    return keywords.get(text) orelse .identifier;
}

pub fn nextToken(self: *@This()) Token {
    self.token_start = self.loc.offset;
    const loc = self.loc;
    const ch = self.nextChar() orelse return .{
        .kind = .eof,
        .loc = self.loc,
        .text = "",
    };

    var kind = Token.Kind.literal_char;

    switch (ch) {
        ' ', '\t', '\r', '\n', '#' => {
            self.lexWhitespace(ch == '#');
            kind = .whitespace;
        },
        '{' => kind = .left_brace,
        '}' => kind = .right_brace,
        '[' => kind = .left_bracket,
        ']' => kind = .right_bracket,
        '(' => kind = .left_paren,
        ')' => kind = .right_paren,
        '=' => kind = .equal,
        '|' => kind = .pipe,
        '-' => kind = .dash,
        '.' => kind = .dot,
        '%' => {
            if (self.peekChar() orelse 0 == '%') {
                _ = self.nextChar();
                kind = .percent_percent;
            }
        },
        'a'...'z', 'A'...'Z', '_' => {
            kind = self.lexIdentifier();
        },
        '\\' => {
            if (self.nextChar()) |_| {
                kind = .literal_char;
            } else {
                kind = .@"error";
            }
        },
        else => {},
    }

    return .{
        .kind = kind,
        .loc = loc,
        .text = self.tokenText(),
    };
}
