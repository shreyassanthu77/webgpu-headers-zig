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

    log.info("schema.copyright = {s}", .{schema.copyright});
    log.info("schema.name = {s}", .{schema.name});

    for (schema.bitflags) |bitflag| {
        log.info("bitflag {s}", .{bitflag.name});
        for (bitflag.entries) |entry| {
            log.info("    {s}", .{entry.name});
            if (entry.value_combination) |value_combination| {
                for (value_combination) |value| {
                    log.info("        - {s}", .{value});
                }
            }
        }
    }

    for (schema.callbacks) |callback| {
        log.info("callback {s} - {t}", .{ callback.name, callback.style });
        for (callback.args) |arg| {
            log.info("    {s}: {s}{s} pointer: {t} owned: {} def: {}", .{
                arg.name,
                if (arg.optional) "?" else "",
                arg.type,
                arg.pointer,
                arg.passed_with_ownership orelse false,
                arg.default,
            });
        }
    }

    for (schema.constants) |constant| {
        log.info("const {s} = {s}", .{ constant.name, constant.value });
    }

    for (schema.enums) |en| {
        log.info("enum {s}", .{en.name});
        for (en.entries) |maybe_entry| {
            const entry = maybe_entry orelse {
                log.info("    _", .{});
                continue;
            };
            log.info("    {s}", .{entry.name});
        }
    }

    for (schema.functions) |func| {
        log.info("fn {s}", .{func.name});
        if (func.returns) |ret| {
            log.info("    returns {s}", .{ret.type});
        }
        for (func.args) |arg| {
            log.info("    {s}: {s}{s} pointer: {t} owned: {} def: {}", .{
                arg.name,
                if (arg.optional) "?" else "",
                arg.type,
                arg.pointer,
                arg.passed_with_ownership orelse false,
                arg.default,
            });
        }
    }

    for (schema.objects) |obj| {
        log.info("obj {s}", .{obj.name});
        for (obj.methods) |method| {
            log.info("    fn {s}", .{method.name});
            if (method.returns) |ret| {
                log.info("        returns {s}", .{ret.type});
            }
            for (method.args) |arg| {
                log.info("        {s}: {s}{s} pointer: {t} owned: {} def: {}", .{
                    arg.name,
                    if (arg.optional) "?" else "",
                    arg.type,
                    arg.pointer,
                    arg.passed_with_ownership orelse false,
                    arg.default,
                });
            }
        }
    }

    for (schema.structs) |str| {
        log.info("struct {s}", .{str.name});
        for (str.members) |member| {
            log.info("    {s}: {s}{s} pointer: {t} owned: {} def: {}", .{
                member.name,
                if (member.optional) "?" else "",
                member.type,
                member.pointer,
                member.passed_with_ownership orelse false,
                member.default,
            });
        }
    }

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
        try writer.writeAll(" = packed struct(u32) {\n");

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

        const remaining = 32 - count;
        if (remaining > 0) {
            try writer.print("    _: u{d} = 0,\n\n", .{remaining});
        }

        try writer.writeAll("    pub const none = .{};\n");
        for (bitflag.entries) |entry| {
            const combos = entry.value_combination orelse continue;
            try writeDocString(writer, entry.doc, 1);
            try writer.writeAll("    pub const ");
            try writeIdent(writer, entry.name, .snake);
            try writer.writeAll(" = .{\n");
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

        var value: u32 = 0;
        try writeDocString(writer, en.doc, 0);
        try writer.writeAll("pub const ");
        try writeIdent(writer, en.name, .pascal);
        try writer.writeAll(" = enum(u32) {\n");
        for (en.entries) |entry| {
            defer value += 1;
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
            for (method.args) |arg| {
                if (std.mem.startsWith(u8, arg.type, "array<")) {
                    const inner = arg.type["array<".len .. arg.type.len - 1];
                    try writer.writeAll(", ");
                    try writeIdent(writer, arg.name, .snake);
                    try writer.writeAll("_count: usize, ");
                    try writeIdent(writer, arg.name, .snake);
                    try writer.writeAll(": ?[*]const ");
                    try writeTypeInner(writer, inner, false);
                } else {
                    try writer.writeAll(", ");
                    try writeIdent(writer, arg.name, .snake);
                    try writer.writeAll(": ");
                    try writeArgType(writer, arg);
                }
            }
            if (method.callback) |cb| {
                try writer.writeAll(", callback_info: ");
                const cb_name = cb["callback.".len..];
                try writeIdent(writer, cb_name, .pascal);
                try writer.writeAll("CallbackInfo");
            }
            try writer.writeAll(") callconv(.c) ");
            if (method.returns) |ret| {
                try writeReturnType(writer, ret);
            } else if (method.callback != null) {
                try writer.writeAll("Future");
            } else {
                try writer.writeAll("void");
            }
            try writer.writeAll(";\n");

            // pub const alias
            try writer.writeAll("    pub const ");
            try writeIdent(writer, method.name, .camel);
            try writer.writeAll(" = wgpu");
            try writeIdent(writer, obj.name, .pascal);
            try writeIdent(writer, method.name, .pascal);
            try writer.writeAll(";\n");
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
            const type_str = member.type;
            if (std.mem.startsWith(u8, type_str, "array<")) {
                // array<T> becomes two fields: count (usize) + pointer (?[*]const T)
                const inner = type_str["array<".len .. type_str.len - 1];

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
                if (try writeMemberDefault(writer, member)) {
                    // default was written
                } else {
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
        try writer.writeAll("extern fn wgpu");
        try writeIdent(writer, func.name, .pascal);
        try writer.writeAll("(");
        var first = true;
        for (func.args) |arg| {
            if (!first) try writer.writeAll(", ");
            first = false;
            try writeIdent(writer, arg.name, .snake);
            try writer.writeAll(": ");
            try writeArgType(writer, arg);
        }
        try writer.writeAll(") callconv(.c) ");
        if (func.returns) |ret| {
            try writeReturnType(writer, ret);
        } else {
            try writer.writeAll("void");
        }
        try writer.writeAll(";\n");
        try writer.writeAll("pub const ");
        try writeIdent(writer, func.name, .camel);
        try writer.writeAll(" = wgpu");
        try writeIdent(writer, func.name, .pascal);
        try writer.writeAll(";\n\n");
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
fn writeIdent(writer: *std.Io.Writer, str: []const u8, comptime case: Case) !void {
    const validIdentStart = std.ascii.isAlphabetic(str[0]) or str[0] == '_';
    if (!validIdentStart) {
        try writer.writeAll("@\"");
    }
    try writeCase(writer, str, case);
    if (!validIdentStart) {
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
    const type_str = member.type;

    // Handle array types: array<T> becomes count + pointer pair
    // But we handle these as two fields, so array types are split in the caller.
    // Actually, looking at the C header, array<T> becomes count: usize + ptr: ?[*]const T
    // But the JSON has these as single members. The C generator splits them.
    // For Zig we need to handle this: the member type is the pointer part,
    // and we need to emit the count field before it.

    if (std.mem.startsWith(u8, type_str, "array<")) {
        // array types should be handled before calling writeMemberType
        unreachable;
    }

    // Handle pointer wrapping
    const is_optional = member.optional;
    const pointer = member.pointer;

    if (pointer != .none) {
        if (is_optional) {
            try writer.writeAll("?");
        }
        // c_void pointers are raw data buffers → multi-pointer [*]
        // everything else is a single-item pointer → *
        const is_raw = std.mem.eql(u8, type_str, "c_void");
        switch (pointer) {
            .immutable => try writer.writeAll(if (is_raw) "[*]const " else "*const "),
            .mutable => try writer.writeAll(if (is_raw) "[*]" else "*"),
            .none => unreachable,
        }
    } else if (is_optional) {
        // Optional non-pointer object types are nullable pointers already
        // For non-object types, optional means something different
        if (std.mem.startsWith(u8, type_str, "object.")) {
            // object types are already pointers, optional makes them nullable
            // handled below
        } else {
            try writer.writeAll("?");
        }
    }

    try writeTypeInner(writer, type_str, is_optional);
}

fn writeTypeInner(writer: *std.Io.Writer, type_str: []const u8, optional: bool) !void {
    if (std.mem.eql(u8, type_str, "uint32")) {
        try writer.writeAll("u32");
    } else if (std.mem.eql(u8, type_str, "uint64")) {
        try writer.writeAll("u64");
    } else if (std.mem.eql(u8, type_str, "int32")) {
        try writer.writeAll("i32");
    } else if (std.mem.eql(u8, type_str, "uint16")) {
        try writer.writeAll("u16");
    } else if (std.mem.eql(u8, type_str, "float32") or std.mem.eql(u8, type_str, "nullable_float32")) {
        try writer.writeAll("f32");
    } else if (std.mem.eql(u8, type_str, "float64_supertype")) {
        try writer.writeAll("f64");
    } else if (std.mem.eql(u8, type_str, "usize")) {
        try writer.writeAll("usize");
    } else if (std.mem.eql(u8, type_str, "bool")) {
        try writer.writeAll("Bool");
    } else if (std.mem.eql(u8, type_str, "optional_bool") or std.mem.eql(u8, type_str, "enum.optional_bool")) {
        try writer.writeAll("Bool.Optional");
    } else if (std.mem.eql(u8, type_str, "string_with_default_empty") or
        std.mem.eql(u8, type_str, "out_string") or
        std.mem.eql(u8, type_str, "nullable_string"))
    {
        try writer.writeAll("String");
    } else if (std.mem.eql(u8, type_str, "c_void")) {
        try writer.writeAll("anyopaque");
    } else if (std.mem.startsWith(u8, type_str, "enum.")) {
        const name = type_str["enum.".len..];
        if (std.mem.eql(u8, name, "optional_bool")) {
            try writer.writeAll("Bool.Optional");
        } else {
            try writeIdent(writer, name, .pascal);
        }
    } else if (std.mem.startsWith(u8, type_str, "struct.")) {
        const name = type_str["struct.".len..];
        try writeIdent(writer, name, .pascal);
    } else if (std.mem.startsWith(u8, type_str, "object.")) {
        const name = type_str["object.".len..];
        if (optional) {
            try writer.writeAll("?");
        }
        try writeIdent(writer, name, .pascal);
    } else if (std.mem.startsWith(u8, type_str, "bitflag.")) {
        const name = type_str["bitflag.".len..];
        try writeIdent(writer, name, .pascal);
    } else if (std.mem.startsWith(u8, type_str, "callback.")) {
        // Callback info struct types - these are passed by value in C
        // The naming pattern is the callback name + "CallbackInfo"
        const name = type_str["callback.".len..];
        try writeIdent(writer, name, .pascal);
        try writer.writeAll("CallbackInfo");
    } else {
        log.err("Unknown type: {s}", .{type_str});
        try writer.writeAll("@\"UNKNOWN_");
        try writer.writeAll(type_str);
        try writer.writeAll("\"");
    }
}

fn writeMemberDefault(writer: *std.Io.Writer, member: Schema.Parameter) !bool {
    const default = member.default;
    const type_str = member.type;

    switch (default) {
        .null => return false, // no explicit default
        .bool => |b| {
            // bool defaults: false/true → .false/.true (for Bool type)
            if (std.mem.eql(u8, type_str, "bool")) {
                if (b) {
                    try writer.writeAll(" = .true");
                } else {
                    try writer.writeAll(" = .false");
                }
            } else {
                if (b) {
                    try writer.writeAll(" = true");
                } else {
                    try writer.writeAll(" = false");
                }
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
            } else if (std.mem.eql(u8, s, "zero")) {
                // zero-init the struct
                try writer.writeAll(" = .{}");
            } else if (std.mem.eql(u8, s, "none")) {
                // For bitflags, none = .{}; for enums it's different
                if (std.mem.startsWith(u8, type_str, "bitflag.")) {
                    try writer.writeAll(" = .{}");
                } else {
                    try writer.writeAll(" = .none");
                }
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
    const type_str = member.type;

    // Pointer types (including optional pointers) — must check before type-specific defaults
    if (member.pointer != .none) {
        if (member.optional) {
            try writer.writeAll(" = null");
        }
        return;
    }

    // Optional non-pointer types
    if (member.optional) {
        // Optional objects are already nullable pointers
        if (std.mem.startsWith(u8, type_str, "object.")) {
            try writer.writeAll(" = null");
            return;
        }
        try writer.writeAll(" = null");
        return;
    }

    // String types default to String.NULL
    if (std.mem.eql(u8, type_str, "string_with_default_empty") or
        std.mem.eql(u8, type_str, "out_string") or
        std.mem.eql(u8, type_str, "nullable_string"))
    {
        try writer.writeAll(" = String.NULL");
        return;
    }

    // Non-optional object types: no default (they're required fields)
    if (std.mem.startsWith(u8, type_str, "object.")) {
        return;
    }

    // Numeric types default to 0
    if (std.mem.eql(u8, type_str, "uint32") or
        std.mem.eql(u8, type_str, "uint64") or
        std.mem.eql(u8, type_str, "int32") or
        std.mem.eql(u8, type_str, "uint16") or
        std.mem.eql(u8, type_str, "usize"))
    {
        try writer.writeAll(" = 0");
        return;
    }
    if (std.mem.eql(u8, type_str, "float32") or std.mem.eql(u8, type_str, "nullable_float32")) {
        try writer.writeAll(" = 0.0");
        return;
    }
    if (std.mem.eql(u8, type_str, "float64_supertype")) {
        try writer.writeAll(" = 0.0");
        return;
    }

    // Bool type defaults to .false
    if (std.mem.eql(u8, type_str, "bool")) {
        try writer.writeAll(" = .false");
        return;
    }

    // optional_bool defaults to .undefined
    if (std.mem.eql(u8, type_str, "optional_bool") or std.mem.eql(u8, type_str, "enum.optional_bool")) {
        try writer.writeAll(" = .undefined");
        return;
    }

    // Enum types default to the zero value (first variant or undefined)
    if (std.mem.startsWith(u8, type_str, "enum.")) {
        try writer.writeAll(" = @enumFromInt(0)");
        return;
    }

    // Bitflag types default to none (.{})
    if (std.mem.startsWith(u8, type_str, "bitflag.")) {
        try writer.writeAll(" = .{}");
        return;
    }

    // Struct types default to .{}
    if (std.mem.startsWith(u8, type_str, "struct.")) {
        try writer.writeAll(" = .{}");
        return;
    }

    // Callback info types default to .{}
    if (std.mem.startsWith(u8, type_str, "callback.")) {
        try writer.writeAll(" = .{}");
        return;
    }
}

fn writeArgType(writer: *std.Io.Writer, arg: Schema.Parameter) !void {
    const type_str = arg.type;

    if (arg.pointer != .none) {
        if (arg.optional) {
            try writer.writeAll("?");
        }
        // c_void pointers are raw data buffers → multi-pointer [*]
        // everything else is a single-item pointer → *
        const is_raw = std.mem.eql(u8, type_str, "c_void");
        switch (arg.pointer) {
            .immutable => try writer.writeAll(if (is_raw) "[*]const " else "*const "),
            .mutable => try writer.writeAll(if (is_raw) "[*]" else "*"),
            .none => unreachable,
        }
        try writeTypeInner(writer, type_str, false);
        return;
    }

    if (arg.optional) {
        if (std.mem.startsWith(u8, type_str, "object.")) {
            // optional object -> nullable pointer, handled by writeTypeInner
        } else {
            try writer.writeAll("?");
        }
    }

    try writeTypeInner(writer, type_str, arg.optional);
}

fn writeReturnType(writer: *std.Io.Writer, ret: Schema.Parameter) !void {
    const type_str = ret.type;

    if (ret.pointer != .none) {
        if (ret.optional) {
            try writer.writeAll("?");
        }
        switch (ret.pointer) {
            .immutable => try writer.writeAll("[*]const "),
            .mutable => try writer.writeAll("[*]"),
            .none => unreachable,
        }
        try writeTypeInner(writer, type_str, false);
        return;
    }

    try writeTypeInner(writer, type_str, false);
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
