const std = @import("std");

copyright: []const u8,
name: []const u8,
doc: []const u8,
enum_prefix: u16,

bitflags: []const Bitflag,
callbacks: []const Callback,
constants: []const Constant,
enums: []const Enum,
functions: []const Function,
objects: []const Object,
structs: []const Struct,

pub const Bitflag = struct {
    doc: []const u8 = "",
    name: []const u8,
    entries: []const Entry,

    const Entry = struct {
        doc: []const u8 = "",
        name: []const u8,
        value_combination: ?[]const []const u8 = null,
    };
};

pub const Callback = struct {
    doc: []const u8 = "",
    name: []const u8,
    style: Style,
    args: []const Parameter,

    const Style = enum {
        callback_mode,
        immediate,
    };
};

pub const Constant = struct {
    doc: []const u8 = "",
    name: []const u8,
    value: []const u8,
};

pub const Enum = struct {
    doc: []const u8 = "",
    name: []const u8,
    entries: []const ?Entry,

    const Entry = struct {
        doc: []const u8 = "",
        name: []const u8,
    };
};

pub const Function = struct {
    doc: []const u8 = "",
    name: []const u8,
    returns: ?Parameter = null,
    args: []const Parameter = &.{},
    callback: ?[]const u8 = null,
};

pub const Object = struct {
    doc: []const u8 = "",
    name: []const u8,
    methods: []const Function,
    is_struct: bool = false,
};

pub const Struct = struct {
    doc: []const u8 = "",
    name: []const u8,
    type: Type,
    free_members: bool = false,
    members: []const Parameter = &.{},
    /// set when type == .extension
    extends: []const []const u8 = &.{},

    const Type = enum {
        extensible,
        standalone,
        extensible_callback_arg,
        extension,
    };
};

pub const Parameter = struct {
    doc: []const u8 = "",
    /// empty for return values
    name: []const u8 = "",
    type: []const u8,
    optional: bool = false,
    pointer: Pointer = .none,
    passed_with_ownership: ?bool = null,
    default: std.json.Value = .null,

    const Pointer = enum {
        none,
        immutable,
        mutable,
    };
};
