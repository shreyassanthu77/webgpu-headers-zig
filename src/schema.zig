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
    type: Type,
    optional: bool = false,
    pointer: Pointer = .none,
    passed_with_ownership: ?bool = null,
    default: std.json.Value = .null,

    pub const Pointer = enum {
        none,
        immutable,
        mutable,
    };

    pub const Type = union(enum) {
        // Primitive types
        c_void,
        bool,
        optional_bool,
        nullable_string,
        string_with_default_empty,
        out_string,
        uint16,
        uint32,
        uint64,
        usize,
        int16,
        int32,
        float32,
        nullable_float32,
        float64,
        float64_supertype,
        array_bool,
        array_string,
        array_uint16,
        array_uint32,
        array_uint64,
        array_usize,
        array_int16,
        array_int32,
        array_float32,
        array_float64,

        // Complex types
        array: *Type,
        typedef: []const u8,
        @"enum": []const u8,
        bitflag: []const u8,
        @"struct": []const u8,
        callback: []const u8,
        function_type: []const u8,
        object: []const u8,

        const primitives = std.StaticStringMap(@This()).initComptime(.{
            .{ "c_void", .c_void },
            .{ "bool", .bool },
            .{ "optional_bool", .optional_bool },
            .{ "enum.bool", .bool },
            .{ "enum.optional_bool", .optional_bool },
            .{ "nullable_string", .nullable_string },
            .{ "string_with_default_empty", .string_with_default_empty },
            .{ "out_string", .out_string },
            .{ "uint16", .uint16 },
            .{ "uint32", .uint32 },
            .{ "uint64", .uint64 },
            .{ "usize", .usize },
            .{ "int16", .int16 },
            .{ "int32", .int32 },
            .{ "float32", .float32 },
            .{ "nullable_float32", .nullable_float32 },
            .{ "float64", .float64 },
            .{ "float64_supertype", .float64_supertype },
            .{ "array<bool>", .array_bool },
            .{ "array<string>", .array_string },
            .{ "array<uint16>", .array_uint16 },
            .{ "array<uint32>", .array_uint32 },
            .{ "array<uint64>", .array_uint64 },
            .{ "array<usize>", .array_usize },
            .{ "array<int16>", .array_int16 },
            .{ "array<int32>", .array_int32 },
            .{ "array<float32>", .array_float32 },
            .{ "array<float64>", .array_float64 },
        });

        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
            _ = options;

            const tok: std.json.Token = try source.nextAlloc(allocator, .alloc_if_needed);
            return switch (tok) {
                .string, .allocated_string => |_str| blk: {
                    if (primitives.get(_str)) |primitive| break :blk primitive;
                    var str = _str;
                    const is_array = std.mem.startsWith(u8, str, "array<");
                    if (is_array) str = str["array<".len .. str.len - 1]; // remove "array<" and ">"
                    const dot_idx = std.mem.indexOfScalar(u8, str, '.') orelse break :blk error.UnexpectedToken;
                    const kind = str[0..dot_idx];
                    const name = str[dot_idx + 1 ..];
                    const typ: @This() = if (std.mem.eql(u8, kind, "typedef"))
                        .{ .typedef = name }
                    else if (std.mem.eql(u8, kind, "enum"))
                        if (std.mem.eql(u8, name, "bool"))
                            .bool
                        else if (std.mem.eql(u8, name, "optional_bool"))
                            .optional_bool
                        else
                            .{ .@"enum" = name }
                    else if (std.mem.eql(u8, kind, "bitflag"))
                        .{ .bitflag = name }
                    else if (std.mem.eql(u8, kind, "struct"))
                        .{ .@"struct" = name }
                    else if (std.mem.eql(u8, kind, "callback"))
                        .{ .callback = name }
                    else if (std.mem.eql(u8, kind, "function_type"))
                        .{ .function_type = name }
                    else if (std.mem.eql(u8, kind, "object"))
                        .{ .object = name }
                    else
                        return error.UnexpectedToken;
                    if (is_array) {
                        const alloc = try allocator.create(@This());
                        alloc.* = typ;
                        break :blk .{ .array = alloc };
                    }
                    break :blk typ;
                },
                else => error.UnexpectedToken,
            };
        }
    };
};
