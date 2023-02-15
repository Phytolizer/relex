const std = @import("std");
const Token = @import("Token.zig");

pub const Relex = struct {
    definitions: Definitions,
    rules: Rules,

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        self.definitions.deinit(a);
        self.rules.deinit(a);
    }
};

pub const Definitions = struct {
    aliases: []Alias,
    token_names: [][]const u8,

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        for (self.aliases) |alias| {
            alias.deinit(a);
        }
        a.free(self.aliases);
        a.free(self.token_names);
    }
};

pub const Alias = struct {
    name: []const u8,
    regex: []Token,

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        a.free(self.regex);
    }
};

pub const Rules = struct {
    rules: []Rule,

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        for (self.rules) |rule| {
            rule.deinit(a);
        }
        a.free(self.rules);
    }
};

pub const Rule = struct {
    pattern: []Token,
    action: []const u8,

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        a.free(self.pattern);
    }
};
