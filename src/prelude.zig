const std = @import("std");
const builtin = @import("builtin");

pub const Bool = enum(u32) {
    false = 0,
    true = 1,

    pub fn from(value: bool) Bool {
        return @enumFromInt(@intFromBool(value));
    }

    pub fn into(self: Bool) bool {
        return @bitCast(@as(u1, @intCast(@intFromEnum(self))));
    }

    pub fn intoOptional(self: Bool) Optional {
        return .fromBool(self);
    }

    pub const Optional = enum(u32) {
        false = 0,
        true = 1,
        undefined = 2,

        pub fn from(value: ?bool) Optional {
            return switch (value) {
                null => .undefined,
                else => @enumFromInt(@intFromBool(value.?)),
            };
        }

        pub fn fromBool(value: Bool) Optional {
            return @enumFromInt(@intFromEnum(value));
        }

        pub fn into(self: Optional) ?bool {
            return switch (self) {
                .undefined => null,
                else => @bitCast(@as(?bool, @intCast(@intFromEnum(self)))),
            };
        }

        pub fn unwrap(self: Optional) Bool {
            return switch (self) {
                .undefined => unreachable,
                else => @enumFromInt(@intFromEnum(self)),
            };
        }
    };
};

pub const String = extern struct {
    ptr: ?[*]const u8,
    len: usize,

    pub fn from(str: []const u8) String {
        return .{ .ptr = str.ptr, .len = str.len };
    }

    /// Only use this when you know the ptr is not null or the length is correct.
    /// All webgpu funtions that give you string will always have a length.
    pub fn slice(self: String) []const u8 {
        return self.ptr[0..self.len];
    }

    pub fn safeSlice(self: String) []const u8 {
        const ptr = self.ptr orelse return "";
        const len = self.len;
        return switch (len) {
            0 => "",
            WGPU_STRLEN => std.mem.span(ptr),
            else => ptr[0..len],
        };
    }

    pub const NULL = String{ .ptr = null, .len = WGPU_STRLEN };

    pub const WGPU_STRLEN = std.math.maxInt(usize);
};

const uint32_max = std.math.maxInt(u32);
const uint64_max = std.math.maxInt(u64);
const usize_max = std.math.maxInt(usize);
const nan =
    if (builtin.zig_version.major == 0 and builtin.zig_version.minor >= 16)
        std.zig.c_translation.builtins.nanf("")
    else
        std.zig.c_builtins.nanf("");
