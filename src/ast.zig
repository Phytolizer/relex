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
    regex: *NfaNode,

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        self.regex.deinit(a);
        a.destroy(self.regex);
    }
};

pub const NfaNode = struct {
    edge: Edge = .epsilon,
    next: [2]?*NfaNode = .{ null, null },

    pub fn init(a: std.mem.Allocator) !*@This() {
        const result = try a.create(@This());
        result.* = .{};
        return result;
    }

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        for (self.next) |next| {
            if (next) |n| {
                n.deinit(a);
                a.destroy(n);
            }
        }
    }

    pub const Edge = union(enum) {
        char: u8,
        epsilon,
        character_class: CharacterClass,
        empty,
    };
};

/// Enough to hold a set of ASCII characters. (2**7)
pub const CharacterClass = std.StaticBitSet(128);

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
