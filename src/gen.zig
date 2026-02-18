const std = @import("std");
const builtin = @import("builtin");
const Schema = @import("schema.zig");
const log = std.log.scoped(.@"webgpu-zig-bindgen");

fn generateBindings(gpa: std.mem.Allocator, input_contents: []const u8, writer: *std.Io.Writer) !void {
    var schema_parsed: std.json.Parsed(Schema) = try std.json.parseFromSlice(Schema, gpa, input_contents, .{
        .ignore_unknown_fields = true,
    });
    defer schema_parsed.deinit();
    const schema = schema_parsed.value;

    const prelude = @embedFile("./prelude.zig");
    try writer.writeAll(prelude);
    try writer.writeAll("\n");

    for (schema.constants) |constant| {
        try writer.writeAll("pub const ");
        try writeIdent(writer, constant.name, .snake);
        try writer.writeAll(" = ");
        try writer.writeAll(constant.value);
        try writer.writeAll(";\n");
    }
    try writer.writeAll("\n");

    for (schema.bitflags) |bitflag| {
        try writeDocString(writer, bitflag.doc, 0);
        try writer.writeAll("pub const ");
        try writeIdent(writer, bitflag.name, .pascal);
        try writer.writeAll(" = packed struct(u64) {\n");

        var count: usize = 0;
        // Skip the first entry, which is the "none" entry.
        for (bitflag.entries[1..]) |entry| {
            if (entry.value_combination != null) {
                continue;
            }

            try writeDocString(writer, entry.doc, 1);
            try writer.writeAll("    ");
            try writeIdent(writer, entry.name, .snake);
            try writer.writeAll(": bool = false,\n");
            count += 1;
        }

        const remaining = 64 - count;
        if (remaining > 0) {
            try writer.print("    _: u{d} = 0,\n\n", .{remaining});
        }

        try writer.writeAll("    pub const none: @This() = .{};\n");
        for (bitflag.entries) |entry| {
            const combos = entry.value_combination orelse continue;
            try writeDocString(writer, entry.doc, 1);
            try writer.writeAll("    pub const ");
            try writeIdent(writer, entry.name, .snake);
            try writer.writeAll(": @This() = .{\n");
            for (combos) |combo| {
                try writer.writeAll("        .");
                try writeIdent(writer, combo, .snake);
                try writer.writeAll(" = true,\n");
            }
            try writer.writeAll("    };\n");
        }

        try writer.writeAll("};\n\n");
    }

    for (schema.enums) |en| {
        if (std.mem.eql(u8, en.name, "optional_bool")) continue;

        try writeDocString(writer, en.doc, 0);
        try writer.writeAll("pub const ");
        try writeIdent(writer, en.name, .pascal);
        try writer.writeAll(" = enum(u32) {\n");
        for (en.entries) |entry| {
            const e = entry orelse continue;
            try writeDocString(writer, e.doc, 1);
            try writer.writeAll("    ");
            try writeIdent(writer, e.name, .snake);
            try writer.writeAll(",\n");
        }
        try writer.writeAll("    _,\n");

        try writer.writeAll("};\n\n");
    }

    // Callback function pointer types
    for (schema.callbacks) |callback| {
        try writeDocString(writer, callback.doc, 0);
        try writer.writeAll("pub const ");
        try writeIdent(writer, callback.name, .pascal);
        try writer.writeAll("Callback = *const fn(\n");
        for (callback.args) |arg| {
            try writer.writeAll("    ");
            try writeArgType(writer, arg);
            try writer.writeAll(",\n");
        }
        try writer.writeAll("    ?*anyopaque,\n");
        try writer.writeAll("    ?*anyopaque,\n");
        try writer.writeAll(") callconv(.c) void;\n\n");
    }

    // Callback info structs
    for (schema.callbacks) |callback| {
        try writer.writeAll("pub const ");
        try writeIdent(writer, callback.name, .pascal);
        try writer.writeAll("CallbackInfo = extern struct {\n");
        try writer.writeAll("    next_in_chain: ?*ChainedStruct = null,\n");
        if (callback.style == .callback_mode) {
            try writer.writeAll("    mode: CallbackMode = @enumFromInt(0),\n");
        }
        try writer.writeAll("    callback: ?");
        try writeIdent(writer, callback.name, .pascal);
        try writer.writeAll("Callback = null,\n");
        try writer.writeAll("    userdata1: ?*anyopaque = null,\n");
        try writer.writeAll("    userdata2: ?*anyopaque = null,\n");
        try writeCallbackInfoHelpers(writer, callback);
        try writer.writeAll("};\n\n");
    }

    for (schema.objects) |obj| {
        std.debug.assert(!obj.is_struct);

        try writeDocString(writer, obj.doc, 0);
        try writer.writeAll("pub const ");
        try writeIdent(writer, obj.name, .pascal);
        try writer.writeAll(" = *opaque {\n");

        // addRef
        try writer.writeAll("    extern fn wgpu");
        try writeIdent(writer, obj.name, .pascal);
        try writer.writeAll("AddRef(self: @This()) callconv(.c) void;\n");
        try writer.writeAll("    pub const addRef = wgpu");
        try writeIdent(writer, obj.name, .pascal);
        try writer.writeAll("AddRef;\n");

        // release
        try writer.writeAll("    extern fn wgpu");
        try writeIdent(writer, obj.name, .pascal);
        try writer.writeAll("Release(self: @This()) callconv(.c) void;\n");
        try writer.writeAll("    /// Releases the object and its underlying resources.\n");
        try writer.writeAll("    pub const release = wgpu");
        try writeIdent(writer, obj.name, .pascal);
        try writer.writeAll("Release;\n");

        // methods
        for (obj.methods) |method| {
            try writer.writeAll("\n");
            try writeDocString(writer, method.doc, 1);

            // extern fn declaration
            try writer.writeAll("    extern fn wgpu");
            try writeIdent(writer, obj.name, .pascal);
            try writeIdent(writer, method.name, .pascal);
            try writer.writeAll("(self: @This()");
            try writeParameterList(writer, method.args, method.callback, .extern_decl, true);
            try writer.writeAll(") callconv(.c) ");
            try writeCallableReturn(writer, method.returns, method.callback != null);
            try writer.writeAll(";\n");

            // wrapper pub fn
            try writer.writeAll("    pub inline fn ");
            try writeIdent(writer, method.name, .camel);
            try writer.writeAll("(self: @This()");
            try writeParameterList(writer, method.args, method.callback, .wrapper_decl, true);
            try writer.writeAll(") ");
            try writeCallableReturn(writer, method.returns, method.callback != null);
            try writer.writeAll(" {\n");
            try writer.writeAll("        return wgpu");
            try writeIdent(writer, obj.name, .pascal);
            try writeIdent(writer, method.name, .pascal);
            try writer.writeAll("(self");
            try writeParameterList(writer, method.args, method.callback, .call, true);
            try writer.writeAll(");\n");
            try writer.writeAll("    }\n");
        }

        try writer.writeAll("};\n\n");
    }

    try writer.writeAll("pub const ChainedStruct = extern struct {\n");
    try writer.writeAll("    next: ?*ChainedStruct = null,\n");
    try writer.writeAll("    s_type: SType = @enumFromInt(0),\n");
    try writer.writeAll("};\n\n");

    for (schema.structs) |str| {
        try writeDocString(writer, str.doc, 0);
        try writer.writeAll("pub const ");
        try writeIdent(writer, str.name, .pascal);
        try writer.writeAll(" = extern struct {\n");

        switch (str.type) {
            .extensible, .extensible_callback_arg => {
                try writer.writeAll("    next_in_chain: ?*ChainedStruct = null,\n");
            },
            .extension => {
                try writer.writeAll("    chain: ChainedStruct = .{ .s_type = .");
                try writeIdent(writer, str.name, .snake);
                try writer.writeAll(" },\n");
            },
            .standalone => {},
        }

        for (str.members) |member| {
            if (arrayInnerType(member.type)) |inner| {
                // array<T> becomes two fields: count (usize) + pointer (?[*]const T)

                // Count field: {name}_count or special naming
                try writer.writeAll("    ");
                try writeIdent(writer, member.name, .snake);
                try writer.writeAll("_count: usize = 0,\n");

                // Pointer field
                try writeDocString(writer, member.doc, 1);
                try writer.writeAll("    ");
                try writeIdent(writer, member.name, .snake);
                try writer.writeAll(": ?[*]const ");
                try writeTypeInner(writer, inner, false);
                try writer.writeAll(" = null,\n");
            } else {
                try writeDocString(writer, member.doc, 1);
                try writer.writeAll("    ");
                try writeIdent(writer, member.name, .snake);
                try writer.writeAll(": ");
                try writeMemberType(writer, member);
                if (!(try writeMemberDefault(writer, member))) {
                    // No explicit default: zero-init enums/structs/objects as appropriate
                    try writeImplicitDefault(writer, member);
                }
                try writer.writeAll(",\n");
            }
        }

        // free_members method for structs that need it
        if (str.free_members) {
            try writer.writeAll("\n    extern fn wgpu");
            try writeIdent(writer, str.name, .pascal);
            try writer.writeAll("FreeMembers(self: @This()) callconv(.c) void;\n");
            try writer.writeAll("    pub const freeMembers = wgpu");
            try writeIdent(writer, str.name, .pascal);
            try writer.writeAll("FreeMembers;\n");
        }

        try writer.writeAll("};\n\n");
    }

    // Global functions
    for (schema.functions) |func| {
        try writeDocString(writer, func.doc, 0);

        // extern fn declaration
        try writer.writeAll("extern fn wgpu");
        try writeIdent(writer, func.name, .pascal);
        try writer.writeAll("(");
        try writeParameterList(writer, func.args, func.callback, .extern_decl, false);
        try writer.writeAll(") callconv(.c) ");
        try writeCallableReturn(writer, func.returns, func.callback != null);
        try writer.writeAll(";\n");

        // wrapper pub fn
        try writer.writeAll("pub inline fn ");
        try writeIdent(writer, func.name, .camel);
        try writer.writeAll("(");
        try writeParameterList(writer, func.args, func.callback, .wrapper_decl, false);
        try writer.writeAll(") ");
        try writeCallableReturn(writer, func.returns, func.callback != null);
        try writer.writeAll(" {\n");
        try writer.writeAll("    return wgpu");
        try writeIdent(writer, func.name, .pascal);
        try writer.writeAll("(");
        try writeParameterList(writer, func.args, func.callback, .call, false);
        try writer.writeAll(");\n");
        try writer.writeAll("}\n\n");
    }
}

fn writeDocString(writer: *std.Io.Writer, str: []const u8, indent: usize) !void {
    if (str.len == 0 or std.mem.eql(u8, str, "TODO\n")) return;

    var lines = std.mem.splitScalar(u8, str, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \n");
        if (trimmed.len == 0) continue;
        try writer.splatByteAll(' ', indent * 4);
        try writer.print("/// {s}\n", .{line});
    }
}

const Case = enum { camel, pascal, snake };

const zig_keywords = std.StaticStringMap(void).initComptime(.{
    .{"addrspace"},
    .{"align"},
    .{"allowzero"},
    .{"and"},
    .{"anyframe"},
    .{"anytype"},
    .{"asm"},
    .{"async"},
    .{"await"},
    .{"break"},
    .{"callconv"},
    .{"catch"},
    .{"comptime"},
    .{"const"},
    .{"continue"},
    .{"defer"},
    .{"else"},
    .{"enum"},
    .{"errdefer"},
    .{"error"},
    .{"export"},
    .{"extern"},
    .{"false"},
    .{"fn"},
    .{"for"},
    .{"if"},
    .{"inline"},
    .{"linksection"},
    .{"noalias"},
    .{"noinline"},
    .{"nosuspend"},
    .{"opaque"},
    .{"or"},
    .{"orelse"},
    .{"packed"},
    .{"pub"},
    .{"resume"},
    .{"return"},
    .{"struct"},
    .{"suspend"},
    .{"switch"},
    .{"test"},
    .{"threadlocal"},
    .{"type"},
    .{"true"},
    .{"try"},
    .{"union"},
    .{"unreachable"},
    .{"usingnamespace"},
    .{"var"},
    .{"volatile"},
    .{"while"},
});

fn isZigKeyword(str: []const u8) bool {
    return zig_keywords.has(str);
}

fn isValidIdent(str: []const u8) bool {
    if (str.len == 0) return false;
    if (!(std.ascii.isAlphabetic(str[0]) or str[0] == '_')) return false;
    for (str[1..]) |c| {
        if (!(std.ascii.isAlphanumeric(c) or c == '_')) return false;
    }
    return true;
}

fn writeIdent(writer: *std.Io.Writer, str: []const u8, comptime case: Case) !void {
    const escaped = !isValidIdent(str) or isZigKeyword(str);
    if (escaped) {
        try writer.writeAll("@\"");
    }
    try writeCase(writer, str, case);
    if (escaped) {
        try writer.writeAll("\"");
    }
}
fn writeCase(writer: *std.Io.Writer, str: []const u8, comptime case: Case) !void {
    if (case == .snake) {
        try writer.writeAll(str);
        return;
    }
    var capitalize = case == .pascal;
    for (str) |c| {
        if (c == '_') {
            capitalize = true;
            continue;
        }
        const ch = if (capitalize) std.ascii.toUpper(c) else c;
        try writer.writeByte(ch);
        capitalize = false;
    }
}

fn writeMemberType(writer: *std.Io.Writer, member: Schema.Parameter) !void {
    // Array types are split before calling this function.
    if (arrayInnerType(member.type) != null) {
        // array types should be handled before calling writeMemberType
        unreachable;
    }

    try writeParameterType(writer, member, .single, true);
}

fn writeTypeInner(writer: *std.Io.Writer, typ: Schema.Parameter.Type, optional: bool) !void {
    switch (typ) {
        .uint16 => try writer.writeAll("u16"),
        .uint32 => try writer.writeAll("u32"),
        .uint64 => try writer.writeAll("u64"),
        .usize => try writer.writeAll("usize"),
        .int16 => try writer.writeAll("i16"),
        .int32 => try writer.writeAll("i32"),
        .float32, .nullable_float32 => try writer.writeAll("f32"),
        .float64, .float64_supertype => try writer.writeAll("f64"),

        .bool => try writer.writeAll("Bool"),
        .optional_bool => try writer.writeAll("Bool.Optional"),
        .string_with_default_empty, .out_string, .nullable_string => try writer.writeAll("String"),
        .c_void => try writer.writeAll("anyopaque"),

        .typedef => |name| try writeIdent(writer, name, .pascal),
        .@"enum" => |name| try writeIdent(writer, name, .pascal),
        .@"struct" => |name| try writeIdent(writer, name, .pascal),
        .bitflag => |name| try writeIdent(writer, name, .pascal),
        .object => |name| {
            if (optional) {
                try writer.writeAll("?");
            }
            try writeIdent(writer, name, .pascal);
        },
        .callback => |name| {
            try writeIdent(writer, name, .pascal);
            try writer.writeAll("CallbackInfo");
        },
        .function_type => |name| {
            try writeIdent(writer, name, .pascal);
            try writer.writeAll("Callback");
        },

        .array => unreachable,
        .array_bool => try writer.writeAll("bool"),
        .array_string => try writer.writeAll("String"),
        .array_uint16 => try writer.writeAll("u16"),
        .array_uint32 => try writer.writeAll("u32"),
        .array_uint64 => try writer.writeAll("u64"),
        .array_usize => try writer.writeAll("usize"),
        .array_int16 => try writer.writeAll("i16"),
        .array_int32 => try writer.writeAll("i32"),
        .array_float32 => try writer.writeAll("f32"),
        .array_float64 => try writer.writeAll("f64"),
    }
}

fn writeMemberDefault(writer: *std.Io.Writer, member: Schema.Parameter) !bool {
    const default = member.default;
    const typ = member.type;

    switch (default) {
        .null => return false, // no explicit default
        .bool => |b| {
            const bool_default = if (b) " = true" else " = false";
            const wgpu_bool_default = if (b) " = .true" else " = .false";
            switch (typ) {
                .bool => try writer.writeAll(wgpu_bool_default),
                else => try writer.writeAll(bool_default),
            }
            return true;
        },
        .integer => |i| {
            try writer.print(" = {d}", .{i});
            return true;
        },
        .float => |f| {
            try writer.print(" = {d}", .{f});
            return true;
        },
        .string => |s| {
            // String defaults like "constant.X", "none", "all", "auto", "zero", "render_attachment"
            if (std.mem.startsWith(u8, s, "constant.")) {
                const name = s["constant.".len..];
                try writer.writeAll(" = ");
                try writeIdent(writer, name, .snake);
            } else if (typ == .bitflag) {
                switch (typ) {
                    .bitflag => |bitflag_name| {
                        if (std.mem.eql(u8, s, "none")) {
                            try writer.writeAll(" = .{}");
                        } else if (std.mem.eql(u8, s, "all")) {
                            try writer.writeAll(" = ");
                            try writeIdent(writer, bitflag_name, .pascal);
                            try writer.writeAll(".all");
                        } else {
                            try writer.writeAll(" = .{ .");
                            try writeIdent(writer, s, .snake);
                            try writer.writeAll(" = true }");
                        }
                    },
                    else => unreachable,
                }
            } else if (std.mem.eql(u8, s, "zero")) {
                // zero-init the struct
                try writer.writeAll(" = .{}");
            } else if (std.mem.eql(u8, s, "none")) {
                try writer.writeAll(" = .none");
            } else if (std.mem.startsWith(u8, s, "0x")) {
                // Hex literal like "0xFFFFFFFF"
                try writer.writeAll(" = ");
                try writer.writeAll(s);
            } else {
                // Enum value like "auto", "all", "render_attachment"
                try writer.writeAll(" = .");
                try writeIdent(writer, s, .snake);
            }
            return true;
        },
        else => return false,
    }
}

fn writeImplicitDefault(writer: *std.Io.Writer, member: Schema.Parameter) !void {
    const typ = member.type;

    // Pointer types (including optional pointers) — must check before type-specific defaults
    if (member.pointer != .none) {
        if (member.optional) {
            try writer.writeAll(" = null");
        }
        return;
    }

    // Optional non-pointer types
    if (member.optional) {
        try writer.writeAll(" = null");
        return;
    }

    switch (typ) {
        .string_with_default_empty, .out_string, .nullable_string => {
            try writer.writeAll(" = String.NULL");
            return;
        },
        .object => {
            // Non-optional object types: no default (required fields).
            return;
        },
        .uint16, .uint32, .uint64, .usize, .int16, .int32 => {
            try writer.writeAll(" = 0");
            return;
        },
        .float32, .nullable_float32, .float64, .float64_supertype => {
            try writer.writeAll(" = 0.0");
            return;
        },
        .bool => {
            try writer.writeAll(" = .false");
            return;
        },
        .optional_bool => {
            try writer.writeAll(" = .undefined");
            return;
        },
        .@"enum" => {
            try writer.writeAll(" = @enumFromInt(0)");
            return;
        },
        .bitflag, .callback => {
            try writer.writeAll(" = .{}");
            return;
        },
        else => return,
    }
}

fn arrayInnerType(typ: Schema.Parameter.Type) ?Schema.Parameter.Type {
    return switch (typ) {
        .array => |child| child.*,
        .array_bool => .bool,
        .array_string => .string_with_default_empty,
        .array_uint16 => .uint16,
        .array_uint32 => .uint32,
        .array_uint64 => .uint64,
        .array_usize => .usize,
        .array_int16 => .int16,
        .array_int32 => .int32,
        .array_float32 => .float32,
        .array_float64 => .float64,
        else => null,
    };
}

const PointerWidth = enum {
    single,
    many,
};

fn writePointerPrefix(
    writer: *std.Io.Writer,
    pointer: Schema.Parameter.Pointer,
    typ: Schema.Parameter.Type,
    comptime width: PointerWidth,
) !void {
    // `anyopaque` cannot be used with many pointers (`[*]anyopaque`), so c_void
    // pointers are represented as single-item opaque pointers.
    const is_raw = switch (typ) {
        .c_void => true,
        else => false,
    };
    switch (pointer) {
        .immutable => {
            if (is_raw or width == .single) {
                try writer.writeAll("*const ");
            } else {
                try writer.writeAll("[*]const ");
            }
        },
        .mutable => {
            if (is_raw or width == .single) {
                try writer.writeAll("*");
            } else {
                try writer.writeAll("[*]");
            }
        },
        .none => unreachable,
    }
}

fn writeParameterType(
    writer: *std.Io.Writer,
    param: Schema.Parameter,
    comptime pointer_width: PointerWidth,
    comptime forward_optional_to_inner: bool,
) !void {
    const typ = param.type;

    if (param.pointer != .none) {
        if (param.optional) {
            try writer.writeAll("?");
        }
        try writePointerPrefix(writer, param.pointer, typ, pointer_width);
        try writeTypeInner(writer, typ, false);
        return;
    }

    if (param.optional) {
        switch (typ) {
            .object => {},
            else => try writer.writeAll("?"),
        }
    }

    try writeTypeInner(writer, typ, if (forward_optional_to_inner) param.optional else false);
}

fn writeExternParameter(writer: *std.Io.Writer, arg: Schema.Parameter) !void {
    if (arrayInnerType(arg.type)) |inner| {
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll("_count: usize, ");
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll(": ?[*]const ");
        try writeTypeInner(writer, inner, false);
        return;
    }

    try writeIdent(writer, arg.name, .snake);
    try writer.writeAll(": ");
    try writeArgType(writer, arg);
}

fn writeWrapperParameter(writer: *std.Io.Writer, arg: Schema.Parameter) !void {
    if (arrayInnerType(arg.type)) |inner| {
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll(": ");
        if (arg.optional) {
            try writer.writeAll("?");
        }
        try writer.writeAll("[]const ");
        try writeTypeInner(writer, inner, false);
        return;
    }

    try writeIdent(writer, arg.name, .snake);
    try writer.writeAll(": ");
    if (arg.pointer == .none and isStringParamType(arg.type)) {
        try writer.writeAll("[]const u8");
    } else {
        try writeArgType(writer, arg);
    }
}

fn writeForwardedArgument(writer: *std.Io.Writer, arg: Schema.Parameter) !void {
    if (arrayInnerType(arg.type) != null) {
        if (arg.optional) {
            try writer.writeAll("if (");
            try writeIdent(writer, arg.name, .snake);
            try writer.writeAll(") |slice| slice.len else 0, if (");
            try writeIdent(writer, arg.name, .snake);
            try writer.writeAll(") |slice| slice.ptr else null");
        } else {
            try writeIdent(writer, arg.name, .snake);
            try writer.writeAll(".len, ");
            try writeIdent(writer, arg.name, .snake);
            try writer.writeAll(".ptr");
        }
        return;
    }

    if (arg.pointer == .none and isStringParamType(arg.type)) {
        try writer.writeAll("String.from(");
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll(")");
        return;
    }

    try writeIdent(writer, arg.name, .snake);
}

fn writeArgType(writer: *std.Io.Writer, arg: Schema.Parameter) !void {
    try writeParameterType(writer, arg, .single, true);
}

fn writeReturnType(writer: *std.Io.Writer, ret: Schema.Parameter) !void {
    try writeParameterType(writer, ret, .many, false);
}

const ParameterListKind = enum {
    extern_decl,
    wrapper_decl,
    call,
};

fn isStringParamType(typ: Schema.Parameter.Type) bool {
    return switch (typ) {
        .string_with_default_empty, .out_string, .nullable_string => true,
        else => false,
    };
}

fn writeUserCallbackArgType(writer: *std.Io.Writer, arg: Schema.Parameter) !void {
    if (arg.pointer == .none and isStringParamType(arg.type)) {
        try writer.writeAll("[]const u8");
    } else {
        try writeArgType(writer, arg);
    }
}

fn writeUserCallbackArgTypes(writer: *std.Io.Writer, args: []const Schema.Parameter) !void {
    for (args, 0..) |arg, i| {
        if (i > 0) try writer.writeAll(", ");
        try writeUserCallbackArgType(writer, arg);
    }
}

fn writeUserCallbackForwardedArg(writer: *std.Io.Writer, arg: Schema.Parameter) !void {
    if (arg.pointer == .none and isStringParamType(arg.type)) {
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll(".safeSlice()");
    } else {
        try writeIdent(writer, arg.name, .snake);
    }
}

fn writeUserCallbackForwardedArgs(writer: *std.Io.Writer, args: []const Schema.Parameter) !void {
    for (args, 0..) |arg, i| {
        if (i > 0) try writer.writeAll(", ");
        try writeUserCallbackForwardedArg(writer, arg);
    }
}

fn writeCallbackTypeRef(writer: *std.Io.Writer, callback_name: []const u8) !void {
    try writeIdent(writer, callback_name, .pascal);
    try writer.writeAll("Callback");
}

fn writeCallbackInfoHelpers(writer: *std.Io.Writer, callback: Schema.Callback) !void {
    if (callback.style == .callback_mode) {
        try writer.writeAll("\n    pub inline fn withMode(self: @This(), mode: CallbackMode) @This() {\n");
        try writer.writeAll("        var info = self;\n");
        try writer.writeAll("        info.mode = mode;\n");
        try writer.writeAll("        return info;\n");
        try writer.writeAll("    }\n");
    }

    try writer.writeAll("\n    pub inline fn from(\n");
    try writer.writeAll("        comptime handler: fn(");
    try writeUserCallbackArgTypes(writer, callback.args);
    try writer.writeAll(") void,\n");
    try writer.writeAll("    ) @This() {\n");
    try writer.writeAll("        return .{\n");
    try writer.writeAll("            .callback = adaptNoContext(handler),\n");
    try writer.writeAll("        };\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    pub inline fn fromContext(\n");
    try writer.writeAll("        comptime Context: type,\n");
    try writer.writeAll("        context: *Context,\n");
    try writer.writeAll("        comptime handler: fn(*Context");
    if (callback.args.len > 0) {
        try writer.writeAll(", ");
        try writeUserCallbackArgTypes(writer, callback.args);
    }
    try writer.writeAll(") void,\n");
    try writer.writeAll("    ) @This() {\n");
    try writer.writeAll("        return .{\n");
    try writer.writeAll("            .callback = adaptContext(Context, handler),\n");
    try writer.writeAll("            .userdata1 = context,\n");
    try writer.writeAll("        };\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    pub inline fn fromContexts(\n");
    try writer.writeAll("        comptime Context1: type,\n");
    try writer.writeAll("        context1: *Context1,\n");
    try writer.writeAll("        comptime Context2: type,\n");
    try writer.writeAll("        context2: *Context2,\n");
    try writer.writeAll("        comptime handler: fn(*Context1, *Context2");
    if (callback.args.len > 0) {
        try writer.writeAll(", ");
        try writeUserCallbackArgTypes(writer, callback.args);
    }
    try writer.writeAll(") void,\n");
    try writer.writeAll("    ) @This() {\n");
    try writer.writeAll("        return .{\n");
    try writer.writeAll("            .callback = adaptContexts(Context1, Context2, handler),\n");
    try writer.writeAll("            .userdata1 = context1,\n");
    try writer.writeAll("            .userdata2 = context2,\n");
    try writer.writeAll("        };\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    fn adaptNoContext(\n");
    try writer.writeAll("        comptime handler: fn(");
    try writeUserCallbackArgTypes(writer, callback.args);
    try writer.writeAll(") void,\n");
    try writer.writeAll("    ) ");
    try writeCallbackTypeRef(writer, callback.name);
    try writer.writeAll(" {\n");
    try writer.writeAll("        return struct {\n");
    try writer.writeAll("            const cb = handler;\n");
    try writer.writeAll("            fn trampoline(\n");
    for (callback.args) |arg| {
        try writer.writeAll("                ");
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll(": ");
        try writeArgType(writer, arg);
        try writer.writeAll(",\n");
    }
    try writer.writeAll("                _: ?*anyopaque,\n");
    try writer.writeAll("                _: ?*anyopaque,\n");
    try writer.writeAll("            ) callconv(.c) void {\n");
    try writer.writeAll("                @call(.always_inline, cb, .{");
    try writeUserCallbackForwardedArgs(writer, callback.args);
    try writer.writeAll("});\n");
    try writer.writeAll("            }\n");
    try writer.writeAll("        }.trampoline;\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    fn adaptContext(\n");
    try writer.writeAll("        comptime Context: type,\n");
    try writer.writeAll("        comptime handler: fn(*Context");
    if (callback.args.len > 0) {
        try writer.writeAll(", ");
        try writeUserCallbackArgTypes(writer, callback.args);
    }
    try writer.writeAll(") void,\n");
    try writer.writeAll("    ) ");
    try writeCallbackTypeRef(writer, callback.name);
    try writer.writeAll(" {\n");
    try writer.writeAll("        return struct {\n");
    try writer.writeAll("            const Ctx = Context;\n");
    try writer.writeAll("            const cb = handler;\n");
    try writer.writeAll("            fn trampoline(\n");
    for (callback.args) |arg| {
        try writer.writeAll("                ");
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll(": ");
        try writeArgType(writer, arg);
        try writer.writeAll(",\n");
    }
    try writer.writeAll("                userdata1: ?*anyopaque,\n");
    try writer.writeAll("                _: ?*anyopaque,\n");
    try writer.writeAll("            ) callconv(.c) void {\n");
    try writer.writeAll("                const ctx: *Ctx = @ptrCast(@alignCast(userdata1 orelse unreachable));\n");
    try writer.writeAll("                @call(.always_inline, cb, .{ctx");
    if (callback.args.len > 0) {
        try writer.writeAll(", ");
        try writeUserCallbackForwardedArgs(writer, callback.args);
    }
    try writer.writeAll("});\n");
    try writer.writeAll("            }\n");
    try writer.writeAll("        }.trampoline;\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    fn adaptContexts(\n");
    try writer.writeAll("        comptime Context1: type,\n");
    try writer.writeAll("        comptime Context2: type,\n");
    try writer.writeAll("        comptime handler: fn(*Context1, *Context2");
    if (callback.args.len > 0) {
        try writer.writeAll(", ");
        try writeUserCallbackArgTypes(writer, callback.args);
    }
    try writer.writeAll(") void,\n");
    try writer.writeAll("    ) ");
    try writeCallbackTypeRef(writer, callback.name);
    try writer.writeAll(" {\n");
    try writer.writeAll("        return struct {\n");
    try writer.writeAll("            const Ctx1 = Context1;\n");
    try writer.writeAll("            const Ctx2 = Context2;\n");
    try writer.writeAll("            const cb = handler;\n");
    try writer.writeAll("            fn trampoline(\n");
    for (callback.args) |arg| {
        try writer.writeAll("                ");
        try writeIdent(writer, arg.name, .snake);
        try writer.writeAll(": ");
        try writeArgType(writer, arg);
        try writer.writeAll(",\n");
    }
    try writer.writeAll("                userdata1: ?*anyopaque,\n");
    try writer.writeAll("                userdata2: ?*anyopaque,\n");
    try writer.writeAll("            ) callconv(.c) void {\n");
    try writer.writeAll("                const ctx1: *Ctx1 = @ptrCast(@alignCast(userdata1 orelse unreachable));\n");
    try writer.writeAll("                const ctx2: *Ctx2 = @ptrCast(@alignCast(userdata2 orelse unreachable));\n");
    try writer.writeAll("                @call(.always_inline, cb, .{ctx1, ctx2");
    if (callback.args.len > 0) {
        try writer.writeAll(", ");
        try writeUserCallbackForwardedArgs(writer, callback.args);
    }
    try writer.writeAll("});\n");
    try writer.writeAll("            }\n");
    try writer.writeAll("        }.trampoline;\n");
    try writer.writeAll("    }\n");
}

fn writeCallbackInfoTypeRef(writer: *std.Io.Writer, callback_ref: []const u8) !void {
    const cb_name = callback_ref["callback.".len..];
    try writeIdent(writer, cb_name, .pascal);
    try writer.writeAll("CallbackInfo");
}

fn writeCallableReturn(writer: *std.Io.Writer, ret: ?Schema.Parameter, has_callback: bool) !void {
    if (ret) |r| {
        try writeReturnType(writer, r);
    } else if (has_callback) {
        try writer.writeAll("Future");
    } else {
        try writer.writeAll("void");
    }
}

fn writeParameterList(
    writer: *std.Io.Writer,
    args: []const Schema.Parameter,
    callback: ?[]const u8,
    kind: ParameterListKind,
    has_leading_param: bool,
) !void {
    var needs_comma = has_leading_param;

    for (args) |arg| {
        if (needs_comma) try writer.writeAll(", ");
        needs_comma = true;

        switch (kind) {
            .extern_decl => try writeExternParameter(writer, arg),
            .wrapper_decl => try writeWrapperParameter(writer, arg),
            .call => try writeForwardedArgument(writer, arg),
        }
    }

    if (callback) |cb| {
        if (needs_comma) try writer.writeAll(", ");
        switch (kind) {
            .extern_decl, .wrapper_decl => {
                try writer.writeAll("callback_info: ");
                try writeCallbackInfoTypeRef(writer, cb);
            },
            .call => try writer.writeAll("callback_info"),
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
// Main
// Some nonsense stuff to make it work with both Zig 0.15 and 0.16
////////////////////////////////////////////////////////////////////////////////

fn lessJuicyMain() !void {
    var gpa_state: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(gpa_state.deinit() == .ok);
    const gpa = gpa_state.allocator();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.skip();

    const input_path = args.next() orelse {
        log.err("No input file specified", .{});
        return error.NoInputFile;
    };
    const input_contents = try std.fs.cwd().readFileAlloc(gpa, input_path, std.math.maxInt(usize));
    defer gpa.free(input_contents);

    const output_path = args.next() orelse {
        log.err("No output file specified", .{});
        return error.NoOutputFile;
    };
    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var out_buf: [20 * 1024]u8 = undefined;
    var out_writer = output_file.writer(&out_buf);

    try generateBindings(gpa, input_contents, &out_writer.interface);
    try out_writer.interface.flush();
}

fn juicyMain(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.skip();

    const input_path = args.next() orelse {
        log.err("No input file specified", .{});
        return error.NoInputFile;
    };
    const input_contents = try std.Io.Dir.cwd().readFileAlloc(io, input_path, gpa, .unlimited);
    defer gpa.free(input_contents);

    const output_path = args.next() orelse {
        log.err("No output file specified", .{});
        return error.NoOutputFile;
    };
    const output_file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer output_file.close(io);

    var out_buf: [20 * 1024]u8 = undefined;
    var out_writer = output_file.writer(io, &out_buf);

    try generateBindings(gpa, input_contents, &out_writer.interface);
    try out_writer.interface.flush();
}

pub const main = switch (builtin.zig_version.major) {
    0 => switch (builtin.zig_version.minor) {
        0...14 => @compileError("At least Zig 0.15 is required"),
        15 => lessJuicyMain,
        else => juicyMain,
    },
    else => @compileError("lol"),
};
