const std = @import("std");

const ast = @import("ast.zig");
const Token = @import("Token.zig");
const Lexer = @import("Lexer.zig");

lexer: Lexer,
a: std.mem.Allocator,
peek_buf: std.ArrayList(Token),

pub const Options = Lexer.Options;

pub fn init(source: []const u8, a: std.mem.Allocator, options: Options) @This() {
    const lexer = Lexer.init(source, options);
    const peek_buf = std.ArrayList(Token).init(a);
    return .{
        .lexer = lexer,
        .a = a,
        .peek_buf = peek_buf,
    };
}

pub fn deinit(self: @This()) void {
    self.peek_buf.deinit();
}

pub fn parse(self: *@This()) !ast.Relex {
    const definitions = try self.parseDefinitions();
    const rules = try self.parseRules();
    return .{
        .definitions = definitions,
        .rules = rules,
    };
}

fn parseDefinitions(self: *@This()) !ast.Definitions {
    var aliases = std.ArrayList(ast.Alias).init(self.a);
    errdefer aliases.deinit();
    var token_names: ?[][]const u8 = null;
    while (true) {
        const token = try self.peek(0);
        switch (token.kind) {
            .percent_percent => return .{
                .aliases = try aliases.toOwnedSlice(),
                .token_names = token_names orelse return error.Parse,
            },
            .kw_alias => try aliases.append(try self.parseAlias()),
            .kw_tokens => token_names = try self.parseTokenNames(),
            else => return error.Parse,
        }
    }
}

fn peek(self: *@This(), distance: usize) !Token {
    while (self.peek_buf.items.len < distance + 1) {
        const token = self.lexer.nextToken();
        try self.peek_buf.append(token);
    }
    return self.peek_buf.items[distance];
}
