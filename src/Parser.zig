const std = @import("std");

const ast = @import("ast.zig");
const Token = @import("Token.zig");
const Lexer = @import("Lexer.zig");
const Queue = @import("queue.zig").Queue;

lexer: Lexer,
a: std.mem.Allocator,
peek_buf: Queue(Token),

pub const Options = Lexer.Options;

pub fn init(source: []const u8, a: std.mem.Allocator, options: Options) @This() {
    const lexer = Lexer.init(source, options);
    const peek_buf = Queue(Token).init(a);
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

fn parseAlias(self: *@This()) !ast.Alias {
    _ = try self.expect(.kw_alias);
    const name = try self.expect(.identifier);
    _ = try self.expect(.equal);
    const regex = try self.parseRegex();
    return .{
        .name = name.text,
        .regex = regex.start,
    };
}

fn parseRegex(self: *@This()) !NodePair {
    var expr = try self.parseConcat();
    errdefer expr.start.deinit(self.a);

    while (self.match(.pipe)) {
        const second = try self.parseConcat();
        errdefer second.start.deinit(self.a);

        const new_start = try ast.NfaNode.init(self.a);
        new_start.next[0] = expr.start;
        new_start.next[1] = second.start;
        expr.start = new_start;

        const new_end = try ast.NfaNode.init(self.a);
        expr.end.next[0] = new_end;
        second.end.next[0] = new_end;
        expr.end = new_end;
    }

    return expr;
}

const NodePair = struct {
    start: *ast.NfaNode,
    end: *ast.NfaNode,
};

fn parseConcat(self: *@This()) !NodePair {
    var expr = if (try self.checkConcatStart())
        try self.parseFactor()
    else
        NodePair{
            .start = try ast.NfaNode.init(self.a),
            .end = try ast.NfaNode.init(self.a),
        };
    errdefer expr.start.deinit(self.a);

    while (try self.checkConcatStart()) {
        const second = try self.parseFactor();
        errdefer second.start.deinit(self.a);

        // concatenation: connect the end of the first to
        // the start of the second

        expr.end.* = second.start.*;

        // don't call destructor, it'll delete the whole thing
        self.a.destroy(second.start);

        expr.end = second.end;
    }

    return expr;
}

fn parseFactor(self: *@This()) !NodePair {
    var expr = try self.parseAtom();
    errdefer expr.start.deinit(self.a);

    if (try self.matchAny(&.{ .plus, .star, .question })) |kind| {
        const new_start = try ast.NfaNode.init(self.a);
        const new_end = try ast.NfaNode.init(self.a);
        new_start.next[0] = expr.start;
        expr.end.next[0] = new_end;

        switch (kind) {
            .star => {
                new_start.next[1] = new_end;
                expr.end.next[1] = new_start;
            },
            .plus => expr.end.next[1] = new_start,
            .question => new_start.next[1] = expr.end,
            else => unreachable,
        }

        expr.start = new_start;
        expr.end = new_end;
    }
}

fn parseAtom(self: *@This()) !NodePair {
    if (try self.match(.left_paren)) {
        const result = try self.parseRegex();
        errdefer result.start.deinit(self.a);
        _ = try self.expect(.right_paren);
        return result;
    } else {
        const start = try ast.NfaNode.init(self.a);
        const end = try ast.NfaNode.init(self.a);
        start.next[0] = end;
        errdefer start.deinit(self.a);

        if (try self.matchAny(&.{ .identifier, .literal_char, .open_bracket })) |kind| {
            start.edge = .{ .character_class = ast.CharacterClass.initEmpty() };
            switch (kind) {
                .identifier, .literal_char => {
                    start.edge.character_class = ast.CharacterClass.initFull();
                },
                .open_bracket => {
                    if (try self.match(.caret))
                        start.edge.character_class = ast.CharacterClass.initFull();
                },
                else => unreachable,
            }
        }
    }
}

fn checkConcatStart(self: *@This()) !bool {
    const first = try self.peek(0);
    return switch (first.kind) {
        .right_paren,
        .pipe,
        .semicolon,
        => false,
        .plus,
        .star,
        .question,
        .left_brace,
        .right_bracket,
        => error.Parse,
        else => true,
    };
}

fn peek(self: *@This(), distance: usize) !Token {
    while (self.peek_buf.items.len < distance + 1) {
        const token = self.lexer.nextToken();
        try self.peek_buf.enqueue(token);
    }
    return self.peek_buf.items[distance];
}

fn next(self: *@This()) !Token {
    return self.peek_buf.dequeue() catch {
        return error.Parse;
    };
}

fn match(self: *@This(), kind: Token.Kind) !bool {
    try self.skipWhitespace();
    const token = self.peek(0);
    if (token.kind == kind) {
        _ = self.next() catch unreachable;
        return true;
    }
    return false;
}

fn matchAny(self: *@This(), kinds: []const Token.Kind) !?Token.Kind {
    try self.skipWhitespace();
    const token = self.peek(0);
    for (kinds) |kind| {
        if (token.kind == kind) {
            _ = self.next() catch unreachable;
            return kind;
        }
    }
    return null;
}

fn skipWhitespace(self: *@This()) !void {
    while (true) {
        const token = try self.peek(0);
        switch (token.kind) {
            .whitespace => {
                _ = self.next() catch unreachable;
            },
            else => return,
        }
    }
}

fn check(self: *@This(), kind: Token.Kind) bool {
    try self.skipWhitespace();
    const token = self.peek(0);
    return token.kind == kind;
}

fn expect(self: *@This(), kind: Token.Kind) !Token {
    try self.skipWhitespace();
    const token = try self.peek(0);
    if (token.kind != kind) return error.Parse;
    _ = self.next() catch unreachable;
    return token;
}
