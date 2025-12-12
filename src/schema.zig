const std = @import("std");

copyright: []const u8,
name: []const u8,
enum_prefix: u32,
doc: []const u8,
typedefs: []const Typedef,
constants: []const Constant,
enums: []const Enum,
bitflags: []const Bitflag,
structs: []const Struct,
callbacks: []const Callback,
functions: []const Function,
objects: []const Object,

// just so parsing doesn't fail
__copyright: []const u8,
_comment: []const u8,

pub const Value64 = union(enum) {
    number: u64,
    usize_max,
    uint32_max,
    uint64_max,
    nan,

    pub fn jsonParse(allocator: std.mem.Allocator, scanner: *std.json.Scanner, options: std.json.ParseOptions) std.json.ParseError(std.json.Scanner)!Value64 {
        const token = try scanner.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
        defer freeAllocated(allocator, token);
        const slice = switch (token) {
            inline .number, .allocated_number, .string, .allocated_string => |slice| slice,
            else => return error.UnexpectedToken,
        };
        if (std.mem.eql(u8, slice, "nan")) {
            return .nan;
        } else if (std.mem.eql(u8, slice, "uint32_max")) {
            return .uint32_max;
        } else if (std.mem.eql(u8, slice, "uint64_max")) {
            return .uint64_max;
        } else if (std.mem.eql(u8, slice, "usize_max")) {
            return .usize_max;
        }
        return .{
            .number = try std.fmt.parseInt(u64, slice, 10),
        };
    }

    fn freeAllocated(allocator: std.mem.Allocator, token: std.json.Token) void {
        switch (token) {
            .allocated_number, .allocated_string => |slice| {
                allocator.free(slice);
            },
            else => {},
        }
    }
};

pub const Typedef = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: []const u8,
    type: []const u8,
};

pub const Constant = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    value: Value64,
    doc: []const u8,
};

pub const Enum = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: []const u8,
    extended: ?bool = null,
    entries: []const ?Entry = &.{},

    pub const Entry = struct {
        name: []const u8,
        namespace: ?[]const u8 = null,
        doc: []const u8,
        value: ?u16 = null,
    };
};

pub const Bitflag = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: []const u8,
    extended: ?bool = null,
    entries: []const ?Entry = &.{},

    pub const Entry = struct {
        name: []const u8,
        namespace: ?[]const u8 = null,
        doc: []const u8,
        value: ?u64 = null,
        value_combination: ?[]const []const u8 = null,
    };
};

pub const Struct = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: []const u8,
    type: ?Type = null,
    extends: ?[]const []const u8 = null,
    free_members: ?bool = null,
    members: []const Function.Parameter = &.{},

    pub const Type = enum {
        extensible,
        extensible_callback_arg,
        extension,
        standalone,
    };
};

pub const Callback = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: []const u8,
    style: Style,
    args: []const Function.Parameter = &.{},

    pub const Style = enum {
        callback_mode,
        immediate,
    };
};

pub const Function = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: []const u8,
    returns: ?Return = null,
    callback: ?[]const u8 = null,
    args: []const Parameter = &.{},

    pub const Return = struct {
        doc: []const u8,
        type: []const u8,
        optional: ?bool = null,
        passed_with_ownership: ?bool = null,
        pointer: ?Pointer = null,
    };

    pub const Parameter = struct {
        name: []const u8,
        doc: []const u8,
        type: []const u8,
        passed_with_ownership: ?bool = null,
        pointer: ?Pointer = null,
        optional: ?bool = null,
        default: ?Default = null,

        pub const Default = union(enum) {
            string: []const u8,
            number: f64,
            boolean: bool,

            pub fn jsonParse(allocator: std.mem.Allocator, scanner: *std.json.Scanner, options: std.json.ParseOptions) std.json.ParseError(std.json.Scanner)!Default {
                const next_token = try scanner.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
                switch (next_token) {
                    .number, .allocated_number => |number| {
                        const value = try std.fmt.parseFloat(f64, number);
                        return .{ .number = value };
                    },
                    .string, .allocated_string => |string| {
                        return .{ .string = string };
                    },
                    .true => {
                        return .{ .boolean = true };
                    },
                    .false => {
                        return .{ .boolean = false };
                    },
                    else => return error.UnexpectedToken,
                }
            }
        };
    };

    pub const Pointer = enum {
        immutable,
        mutable,
    };
};

pub const Object = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: []const u8,
    extended: ?bool = null,
    methods: []const Function,
};
