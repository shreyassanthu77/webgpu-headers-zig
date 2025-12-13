const std = @import("std");
const Schema = @import("schema.zig");

const prelude =
    \\const std = @import("std");
    \\
    \\pub const Proc = ?*const fn () callconv(.C) void;
    \\
    \\pub const Bool = enum(u32) {
    \\    false = 0,
    \\    true = 1,
    \\
    \\    pub inline fn from(b: bool) Bool {
    \\        return if (b) .true else .false;
    \\    }
    \\
    \\    pub inline fn into(self: Bool) bool {
    \\        return self == .true;
    \\    }
    \\};
    \\
    \\pub const String = extern struct {
    \\    data: [*]const u8 = null,
    \\    length: usize = 0,
    \\
    \\    pub inline fn from(s: []const u8) String {
    \\        return .{ .data = s, .length = s.len };
    \\    }
    \\
    \\    pub inline fn slice(self: String) []const u8 {
    \\        return self.data[0..self.length];
    \\    }
    \\
    \\    /// Represents a String that is null according to the webgpu headers spec
    \\    /// [https://webgpu-native.github.io/webgpu-headers/Strings.html]
    \\    pub const NULL = String{ .data = null, .length = std.math.maxInt(usize) };
    \\
    \\    /// Represents a String that is empty according to the webgpu headers spec
    \\    /// [https://webgpu-native.github.io/webgpu-headers/Strings.html]
    \\    pub const EMPTY = String{ .data = "", .length = 0 };
    \\};
    \\
    \\pub const Chained = extern struct {
    \\    next: ?*Chained = null,
    \\    sType: SType,
    \\};
    \\
;

fn gen(allocator: std.mem.Allocator, webgpu_json_contents: []const u8, w: *std.Io.Writer) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const res: std.json.Parsed(Schema) = try std.json.parseFromSlice(Schema, allocator, webgpu_json_contents, .{
        // .ignore_unknown_fields = true,
    });
    defer res.deinit();
    const content = res.value;

    // todo: do our own copyright and module doc
    try writeIndented(alloc, w, '/', 2, "{s}", .{content.copyright}, " {s}");
    try w.writeByte('\n');
    try writeIndented(alloc, w, '/', 2, "{s}", .{content.doc}, "! {s}");
    try w.writeByte('\n');
    try w.writeAll(prelude);
    try w.writeByte('\n');

    std.debug.assert(content.typedefs.len == 0);

    for (content.constants) |constant| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{constant.doc}, "{s}");

        try w.writeAll("pub const ");
        try writeIdentifier(w, constant.name, .snake);
        try w.writeAll(" = ");
        try writeValue64(w, constant.value);
        try w.writeAll(";\n\n");
    }

    for (content.enums) |e| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{e.doc}, "{s}");
        try w.writeAll("pub const ");
        try writeIdentifier(w, e.name, .pascal);
        try w.writeAll(" = enum(u32) {\n");
        var i: usize = 0;
        var reserved: usize = 0;
        for (e.entries, 0..) |maybe_entry, j| {
            if (maybe_entry) |entry| {
                try writeIndented(alloc, w, ' ', 4, "{s}", .{entry.doc}, "/// {s}");
                i = entry.value orelse i;
                defer i += 1;
                try w.splatByteAll(' ', 4);
                try writeIdentifier(w, entry.name, .snake);
                try w.print(" = {d},\n", .{i});
            } else {
                try writeIndented(alloc, w, ' ', 4, "__reserved{d} = {d},\n", .{ reserved, i }, "{s}");
                reserved += 1;
                i += 1;
            }
            if (j < e.entries.len - 1) {
                try w.writeByte('\n');
            }
        }
        try writeIndented(alloc, w, ' ', 4, "\n_,", .{}, "{s}");
        try w.writeAll("};\n\n");
    }

    for (content.bitflags) |bitflag| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{bitflag.doc}, "{s}");
        const bitflag_name = blk: {
            var name_w = std.Io.Writer.Allocating.init(alloc);
            try writeIdentifier(&name_w.writer, bitflag.name, .pascal);
            break :blk try name_w.toOwnedSlice();
        };
        defer alloc.free(bitflag_name);
        try w.print("pub const {s} = packed struct(u32) {{\n", .{bitflag_name});
        var i: usize = 0;
        var reserved: usize = 0;
        var has_value_combos = false;
        for (bitflag.entries) |maybe_entry| {
            if (maybe_entry) |entry| {
                if (entry.value_combination != null) {
                    has_value_combos = true;
                    continue;
                }
                defer i += 1;
                std.debug.assert(entry.value == null);
                try writeIndented(alloc, w, ' ', 4, "{s}", .{entry.doc}, "/// {s}");
                try w.splatByteAll(' ', 4);
                try writeIdentifier(w, entry.name, .snake);
                try w.writeAll(": bool = false,\n\n");
            } else {
                try writeIndented(alloc, w, ' ', 4, "__reserved{d}: bool = false,\n\n", .{reserved}, "{s}");
                reserved += 1;
                i += 1;
            }
        }
        if (i < 32) {
            const padding = 32 - i;
            try writeIndented(alloc, w, ' ', 4, "_: u{d} = 0,", .{padding}, "{s}");
        }
        if (has_value_combos) {
            try w.writeAll("\n");
            for (bitflag.entries) |maybe_entry| {
                const entry = maybe_entry orelse continue;
                const combos = entry.value_combination orelse continue;
                // pub const {s}: @This() = .{ .combo[1] = true };
                try w.splatByteAll(' ', 4);
                try w.writeAll("pub const ");
                try writeIdentifier(w, entry.name, .snake);
                try w.writeAll(": @This() = .{\n");
                for (combos) |combo| {
                    try w.splatByteAll(' ', 8);
                    try w.writeByte('.');
                    try writeIdentifier(w, combo, .snake);
                    try w.writeAll(" = true,\n");
                }
                try writeIndented(alloc, w, ' ', 4, "}};", .{}, "{s}");
            }
        }
        try w.writeAll("};\n\n");
    }

    // Callbacks and implicit CallbackInfo structs (required by async APIs)
    for (content.callbacks) |cb| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{cb.doc}, "{s}");
        const cb_name_pascal = blk: {
            var name_w = std.Io.Writer.Allocating.init(alloc);
            try writeIdentifier(&name_w.writer, cb.name, .pascal);
            break :blk try name_w.toOwnedSlice();
        };
        defer alloc.free(cb_name_pascal);

        // pub const BufferMapCallback = ?*const fn(...) callconv(.C) void;
        try w.writeAll("pub const ");
        try w.print("{s}Callback", .{cb_name_pascal});
        try w.writeAll(" = ?*const fn (");
        for (cb.args, 0..) |arg, i| {
            if (i != 0) try w.writeAll(", ");
            try writeIdentifier(w, arg.name, .snake);
            try w.writeAll(": ");
            try writeType(w, arg.type, arg.pointer, arg.optional);
        }
        // webgpu-headers callbacks always include userdata1/2 at the end
        if (cb.args.len != 0) try w.writeAll(", ");
        try w.writeAll("userdata1: ?*anyopaque, userdata2: ?*anyopaque) callconv(.C) void;\n\n");

        // pub const BufferMapCallbackInfo = extern struct { next_in_chain, mode, callback, userdata1, userdata2 };
        try w.writeAll("pub const ");
        try w.print("{s}CallbackInfo", .{cb_name_pascal});
        try w.writeAll(" = extern struct {\n");
        try w.writeAll("    next_in_chain: ?*Chained = null,\n");
        try w.writeAll("    mode: CallbackMode,\n");
        try w.writeAll("    callback: ");
        try w.print("{s}Callback", .{cb_name_pascal});
        try w.writeAll(" = null,\n");
        try w.writeAll("    userdata1: ?*anyopaque = null,\n");
        try w.writeAll("    userdata2: ?*anyopaque = null,\n");
        try w.writeAll("};\n\n");
    }

    for (content.structs) |s| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{s.doc}, "{s}");
        try w.writeAll("pub const ");
        try writeIdentifier(w, s.name, .pascal);
        try w.writeAll(" = extern struct {\n");

        // Extensible / extension structs participate in chained structs.
        if (s.type) |ty| {
            switch (ty) {
                .extensible, .extensible_callback_arg => {
                    try w.writeAll("    /// Chained struct pointer.\n");
                    try w.writeAll("    next_in_chain: ?*Chained = null,\n");
                },
                .extension => {
                    // Extension structs begin with a chained header (subtype of WGPUChainedStruct).
                    try w.writeAll("    /// Chained header (must have correct `sType`).\n");
                    try w.writeAll("    chain: Chained = .{ .next = null, .sType = .");
                    try writeIdentifier(w, s.name, .snake);
                    try w.writeAll(" },\n");
                },
                .standalone => {},
            }
        }

        for (s.members) |member| {
            // webgpu-headers represents arrays as (count, pointer). The JSON uses array<T>.
            const is_array = std.mem.startsWith(u8, member.type, "array<");
            if (is_array) {
                // Synthesize a count field immediately before the pointer field.
                const count_name = try allocCountFieldName(alloc, member.name);
                defer alloc.free(count_name);
                try w.splatByteAll(' ', 4);
                try w.print("/// Array count for `{s}`.\n", .{member.name});
                try w.splatByteAll(' ', 4);
                try writeIdentifier(w, count_name, .snake);
                try w.writeAll(": usize = 0,\n");
            }

            try writeIndented(alloc, w, ' ', 4, "{s}", .{member.doc}, "/// {s}");
            try w.splatByteAll(' ', 4);
            try writeIdentifier(w, member.name, .snake);
            try w.print(": ", .{});
            try writeType(w, member.type, member.pointer, member.optional);
            try w.writeAll(",\n");
        }
        try w.writeAll("};\n\n");
    }

    for (content.objects) |object| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{object.doc}, "{s}");
        const obj_pascal = blk: {
            var name_w = std.Io.Writer.Allocating.init(alloc);
            try writeIdentifier(&name_w.writer, object.name, .pascal);
            break :blk try name_w.toOwnedSlice();
        };
        defer alloc.free(obj_pascal);

        try w.writeAll("pub const ");
        try w.writeAll(obj_pascal);
        try w.writeAll(" = opaque {\n");

        // Private extern entrypoints + nice Zig methods for editor autocomplete.
        for (object.methods) |m| {
            try writeIndented(alloc, w, ' ', 4, "{s}", .{m.doc}, "/// {s}");

            // Private raw extern (kept next to the wrapper).
            try w.writeAll("    extern fn ");
            try w.writeAll("wgpu");
            try w.writeAll(obj_pascal);
            try writeIdentifier(w, m.name, .pascal);
            try w.writeAll("(");
            try w.writeAll("self: *@This()");
            if (m.args.len != 0) {
                try w.writeAll(", ");
                try writeExternArgs(alloc, w, m.args);
            }
            if (m.callback) |cb_ref| {
                if (std.mem.startsWith(u8, cb_ref, "callback.")) {
                    const cb_name = cb_ref["callback.".len..];
                    const cb_pascal = blk: {
                        var name_w = std.Io.Writer.Allocating.init(alloc);
                        try writeIdentifier(&name_w.writer, cb_name, .pascal);
                        break :blk try name_w.toOwnedSlice();
                    };
                    defer alloc.free(cb_pascal);
                    if (m.args.len != 0) {
                        try w.writeAll(", ");
                    } else {
                        try w.writeAll(", ");
                    }
                    try w.writeAll("callback_info: ");
                    try w.print("{s}CallbackInfo", .{cb_pascal});
                }
            }
            try w.writeAll(")");
            if (m.returns) |ret| {
                try w.writeAll(" ");
                try writeType(w, ret.type, ret.pointer, ret.optional);
            } else {
                try w.writeAll(" void");
            }
            try w.writeAll(";\n");

            try w.writeAll("    pub inline fn ");
            try writeIdentifier(w, m.name, .camel);
            try w.writeAll("(self: *@This()");

            // Wrapper args: use slices for array<...> params, []const u8/?[]const u8 for string params,
            // and optional const struct pointers as ?Struct values for better autocomplete.
            for (m.args) |arg| {
                try w.writeAll(", ");
                try writeIdentifier(w, arg.name, .snake);
                try w.writeAll(": ");
                if (std.mem.startsWith(u8, arg.type, "array<")) {
                    try writeSliceType(w, arg);
                } else if (isInputStringType(arg.type)) {
                    try writeStringSliceType(w, arg.type);
                } else if (isConstStructPtr(arg)) {
                    try writeConstStructValueType(w, arg);
                } else {
                    try writeType(w, arg.type, arg.pointer, arg.optional);
                }
            }

            if (m.callback) |cb_ref| {
                if (std.mem.startsWith(u8, cb_ref, "callback.")) {
                    const cb_name = cb_ref["callback.".len..];
                    const cb_pascal = blk: {
                        var name_w = std.Io.Writer.Allocating.init(alloc);
                        try writeIdentifier(&name_w.writer, cb_name, .pascal);
                        break :blk try name_w.toOwnedSlice();
                    };
                    defer alloc.free(cb_pascal);
                    try w.writeAll(", callback_info: ");
                    try w.print("{s}CallbackInfo", .{cb_pascal});
                }
            }

            try w.writeAll(")");
            if (m.returns) |ret| {
                try w.writeAll(" ");
                try writeType(w, ret.type, ret.pointer, ret.optional);
            } else {
                try w.writeAll(" void");
            }
            try w.writeAll(" {\n");

            // Create lvalues for struct-by-value wrapper args so we can take pointers to the payload.
            for (m.args) |arg| {
                if (isConstStructPtr(arg)) {
                    try w.writeAll("        var ");
                    try writeIdentifier(w, arg.name, .snake);
                    try w.writeAll("__opt = ");
                    try writeIdentifier(w, arg.name, .snake);
                    try w.writeAll(";\n");
                }
            }

            // Call through to the private extern symbol.
            try w.writeAll("        return ");
            try w.writeAll("wgpu");
            try w.writeAll(obj_pascal);
            try writeIdentifier(w, m.name, .pascal);
            try w.writeAll("(");
            try w.writeAll("self");

            for (m.args) |arg| {
                if (std.mem.startsWith(u8, arg.type, "array<")) {
                    try w.writeAll(", ");
                    try writeIdentifier(w, arg.name, .snake);
                    try w.writeAll(".len");
                    try w.writeAll(", ");
                    // arrays are nullable pointers in the ABI; pass null for empty slice
                    try w.writeAll("if (");
                    try writeIdentifier(w, arg.name, .snake);
                    try w.writeAll(".len == 0) null else ");
                    try writeIdentifier(w, arg.name, .snake);
                    try w.writeAll(".ptr");
                } else if (isInputStringType(arg.type)) {
                    try w.writeAll(", ");
                    try writeStringToStringExpr(w, arg);
                } else if (isConstStructPtr(arg)) {
                    try w.writeAll(", ");
                    if (arg.optional != null and arg.optional.? == true) {
                        try w.writeAll("if (");
                        try writeIdentifier(w, arg.name, .snake);
                        try w.writeAll("__opt) |*v| v else null");
                    } else {
                        try w.writeByte('&');
                        try writeIdentifier(w, arg.name, .snake);
                        try w.writeAll("__opt");
                    }
                } else {
                    try w.writeAll(", ");
                    try writeIdentifier(w, arg.name, .snake);
                }
            }
            if (m.callback != null) {
                try w.writeAll(", callback_info");
            }
            try w.writeAll(");\n");
            try w.writeAll("    }\n\n");
        }

        // Refcount helpers
        try w.writeAll("    extern fn wgpu");
        try w.writeAll(obj_pascal);
        try w.writeAll("AddRef(self: *@This()) void;\n");
        try w.writeAll("    extern fn wgpu");
        try w.writeAll(obj_pascal);
        try w.writeAll("Release(self: *@This()) void;\n\n");

        try w.writeAll("    pub inline fn retain(self: *@This()) void { wgpu");
        try w.writeAll(obj_pascal);
        try w.writeAll("AddRef(self); }\n");
        try w.writeAll("    pub inline fn release(self: *@This()) void { wgpu");
        try w.writeAll(obj_pascal);
        try w.writeAll("Release(self); }\n");

        try w.writeAll("};\n\n");
    }

    // ---- Extern declarations (API entrypoints) ----
    // Free functions: private extern decl + public inline wrapper.
    try w.writeAll("extern fn wgpuGetProcAddress(proc_name: String) Proc;\n");
    try w.writeAll("pub inline fn getProcAddress(proc_name: []const u8) Proc { return wgpuGetProcAddress(String.from(proc_name)); }\n\n");

    // Global functions from JSON
    for (content.functions) |f| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{f.doc}, "{s}");
        // private extern
        try w.writeAll("extern fn ");
        try writeWgpuGlobalName(w, f.name);
        try w.writeAll("(");
        try writeExternArgs(alloc, w, f.args);
        try w.writeAll(")");
        if (f.returns) |ret| {
            try w.writeAll(" ");
            try writeType(w, ret.type, ret.pointer, ret.optional);
        } else {
            try w.writeAll(" void");
        }
        try w.writeAll(";\n");

        // public inline wrapper with slice/string ergonomics + optional const struct pointers as ?Struct
        try w.writeAll("pub inline fn ");
        try writeIdentifier(w, f.name, .camel);
        try w.writeAll("(");
        var first: bool = true;
        for (f.args) |arg| {
            if (!first) try w.writeAll(", ");
            first = false;
            try writeIdentifier(w, arg.name, .snake);
            try w.writeAll(": ");
            if (std.mem.startsWith(u8, arg.type, "array<")) {
                try writeSliceType(w, arg);
            } else if (isInputStringType(arg.type)) {
                try writeStringSliceType(w, arg.type);
            } else if (isConstStructPtr(arg)) {
                try writeConstStructValueType(w, arg);
            } else {
                try writeType(w, arg.type, arg.pointer, arg.optional);
            }
        }
        try w.writeAll(")");
        if (f.returns) |ret| {
            try w.writeAll(" ");
            try writeType(w, ret.type, ret.pointer, ret.optional);
        } else {
            try w.writeAll(" void");
        }
        try w.writeAll(" {\n");

        for (f.args) |arg| {
            if (isConstStructPtr(arg)) {
                try w.writeAll("    var ");
                try writeIdentifier(w, arg.name, .snake);
                try w.writeAll("__opt = ");
                try writeIdentifier(w, arg.name, .snake);
                try w.writeAll(";\n");
            }
        }

        try w.writeAll("    return ");
        try writeWgpuGlobalName(w, f.name);
        try w.writeAll("(");
        first = true;
        for (f.args) |arg| {
            if (!first) try w.writeAll(", ");
            first = false;
            if (std.mem.startsWith(u8, arg.type, "array<")) {
                try writeIdentifier(w, arg.name, .snake);
                try w.writeAll(".len, if (");
                try writeIdentifier(w, arg.name, .snake);
                try w.writeAll(".len == 0) null else ");
                try writeIdentifier(w, arg.name, .snake);
                try w.writeAll(".ptr");
            } else if (isInputStringType(arg.type)) {
                try writeStringToStringExpr(w, arg);
            } else if (isConstStructPtr(arg)) {
                if (arg.optional != null and arg.optional.? == true) {
                    try w.writeAll("if (");
                    try writeIdentifier(w, arg.name, .snake);
                    try w.writeAll("__opt) |*v| v else null");
                } else {
                    try w.writeByte('&');
                    try writeIdentifier(w, arg.name, .snake);
                    try w.writeAll("__opt");
                }
            } else {
                try writeIdentifier(w, arg.name, .snake);
            }
        }
        try w.writeAll(");\n");
        try w.writeAll("}\n\n");
    }

    // Implicit FreeMembers externs for structs that allocate output members.
    for (content.structs) |s| {
        if (s.free_members != null and s.free_members.? == true) {
            const s_pascal = blk: {
                var name_w = std.Io.Writer.Allocating.init(alloc);
                try writeIdentifier(&name_w.writer, s.name, .pascal);
                break :blk try name_w.toOwnedSlice();
            };
            defer alloc.free(s_pascal);
            try w.print("extern fn wgpu{s}FreeMembers(value: {s}) void;\n", .{ s_pascal, s_pascal });
            // wrapper name: <structName>FreeMembers (camelCase)
            try w.writeAll("pub inline fn ");
            try writeIdentifier(w, s.name, .camel);
            try w.writeAll("FreeMembers(value: ");
            try w.writeAll(s_pascal);
            try w.writeAll(") void { wgpu");
            try w.writeAll(s_pascal);
            try w.writeAll("FreeMembers(value); }\n\n");
        }
    }
}

const primitive_types = std.StaticStringMap([]const u8).initComptime(&.{
    .{ "c_void", "anyopaque" },
    .{ "bool", "Bool" },
    .{ "nullable_string", "String" },
    .{ "string_with_default_empty", "String" },
    .{ "out_string", "String" },
    .{ "uint16", "u16" },
    .{ "uint32", "u32" },
    .{ "uint64", "u64" },
    .{ "usize", "usize" },
    .{ "int16", "i16" },
    .{ "int32", "i32" },
    .{ "float32", "f32" },
    .{ "nullable_float32", "f32" },
    .{ "float64", "f64" },
    .{ "float64_supertype", "f64" },
});

fn writeType(
    w: *std.Io.Writer,
    type_str: []const u8,
    pointer: ?Schema.Function.Pointer,
    optional: ?bool,
) !void {
    const is_optional = optional != null and optional.? == true;
    const is_array = std.mem.startsWith(u8, type_str, "array<");
    const base_type = if (is_array) type_str["array<".len .. type_str.len - 1] else type_str;

    if (primitive_types.get(base_type)) |prim| {
        // Primitive mappings are already valid Zig identifiers/types; don't case-transform.
        // Arrays in the ABI are passed as nullable pointers (NULL when count == 0).
        if (is_optional or is_array) try w.writeByte('?');

        if (is_array) {
            const ptr = pointer orelse .immutable;
            switch (ptr) {
                .immutable => try w.writeAll("[*]const "),
                .mutable => try w.writeAll("[*]"),
            }
        } else if (pointer) |ptr| {
            switch (ptr) {
                .immutable => try w.writeAll("*const "),
                .mutable => try w.writeAll("*"),
            }
        }

        try w.writeAll(prim);
        return;
    }

    var casing: Casing = .snake;
    var suffix: []const u8 = "";
    var is_object_handle = false;
    const resolved = blk: {
        inline for ([_][]const u8{
            "typedef.",
            "enum.",
            "bitflag.",
            "struct.",
            "object.",
            "callback.",
        }) |prefix| {
            if (std.mem.startsWith(u8, base_type, prefix)) {
                casing = .pascal;
                if (std.mem.eql(u8, prefix, "callback.")) {
                    suffix = "Callback";
                } else if (std.mem.eql(u8, prefix, "object.")) {
                    // object.* types are already opaque pointer handles in the C API.
                    // Model them as pointers to the Zig `opaque` type.
                    is_object_handle = true;
                }
                break :blk base_type[prefix.len..];
            }
        }
        break :blk base_type;
    };

    // Arrays in the ABI are passed as nullable pointers (NULL when count == 0).
    if (is_optional or is_array) try w.writeByte('?');

    if (is_array) {
        const ptr = pointer orelse .immutable;
        switch (ptr) {
            .immutable => try w.writeAll("[*]const "),
            .mutable => try w.writeAll("[*]"),
        }
    } else if (!is_object_handle) {
        if (pointer) |ptr| {
            switch (ptr) {
                .immutable => try w.writeAll("*const "),
                .mutable => try w.writeAll("*"),
            }
        }
    }

    if (is_object_handle) {
        // object handles are pointer types regardless of pointer metadata.
        try w.writeByte('*');
    }
    try writeIdentifier(w, resolved, casing);
    if (suffix.len != 0) try w.writeAll(suffix);
}

fn writeSliceType(w: *std.Io.Writer, p: Schema.Function.Parameter) !void {
    std.debug.assert(std.mem.startsWith(u8, p.type, "array<"));
    const base_type = p.type["array<".len .. p.type.len - 1];
    const is_mut = p.pointer != null and p.pointer.? == .mutable;
    if (is_mut) {
        try w.writeAll("[]");
    } else {
        try w.writeAll("[]const ");
    }
    try writeType(w, base_type, null, null);
}

fn isInputStringType(type_str: []const u8) bool {
    // String-like inputs we want as slices in wrappers.
    return std.mem.eql(u8, type_str, "nullable_string") or
        std.mem.eql(u8, type_str, "string_with_default_empty");
}

fn isConstStructPtr(p: Schema.Function.Parameter) bool {
    // Pattern in the schema for "pointer to input struct" (optional or not).
    // We expose these as Struct / ?Struct in the wrapper for nicer `.{} ` init autocomplete,
    // and then pass *const Struct / ?*const Struct to the extern.
    if (!(p.pointer != null and p.pointer.? == .immutable)) return false;
    return std.mem.startsWith(u8, p.type, "struct.");
}

fn writeConstStructValueType(w: *std.Io.Writer, p: Schema.Function.Parameter) !void {
    std.debug.assert(isConstStructPtr(p));
    if (p.optional != null and p.optional.? == true) try w.writeByte('?');
    const base = p.type["struct.".len..];
    try writeIdentifier(w, base, .pascal);
}

fn writeStringSliceType(w: *std.Io.Writer, type_str: []const u8) !void {
    if (std.mem.eql(u8, type_str, "nullable_string")) {
        try w.writeAll("?[]const u8");
    } else if (std.mem.eql(u8, type_str, "string_with_default_empty")) {
        // Allow null to mean "use default empty semantics".
        try w.writeAll("?[]const u8");
    } else {
        // Fallback: shouldn't happen for now.
        try w.writeAll("[]const u8");
    }
}

fn writeStringToStringExpr(w: *std.Io.Writer, p: Schema.Function.Parameter) !void {
    // Wrapper arg is ?[]const u8; convert to String with correct sentinel behavior.
    if (std.mem.eql(u8, p.type, "nullable_string")) {
        try w.writeAll("if (");
        try writeIdentifier(w, p.name, .snake);
        try w.writeAll(") |s| String.from(s) else String.NULL");
        return;
    }
    if (std.mem.eql(u8, p.type, "string_with_default_empty")) {
        try w.writeAll("if (");
        try writeIdentifier(w, p.name, .snake);
        try w.writeAll(") |s| String.from(s) else String.EMPTY");
        return;
    }
    // Shouldn't be reached: fall back to passing through.
    try writeIdentifier(w, p.name, .snake);
}

fn writeExternArgs(allocator: std.mem.Allocator, w: *std.Io.Writer, args: []const Schema.Function.Parameter) !void {
    var first: bool = true;
    for (args) |arg| {
        const is_array = std.mem.startsWith(u8, arg.type, "array<");
        if (is_array) {
            // Arrays are represented as (count, pointer) in the C ABI.
            const count_name = try allocCountFieldName(allocator, arg.name);
            defer allocator.free(count_name);
            if (!first) try w.writeAll(", ");
            first = false;
            try writeIdentifier(w, count_name, .snake);
            try w.writeAll(": usize");

            try w.writeAll(", ");
            try writeIdentifier(w, arg.name, .snake);
            try w.writeAll(": ");
            try writeType(w, arg.type, arg.pointer, arg.optional);
            continue;
        }

        if (!first) try w.writeAll(", ");
        first = false;
        try writeIdentifier(w, arg.name, .snake);
        try w.writeAll(": ");
        try writeType(w, arg.type, arg.pointer, arg.optional);
    }
}

fn allocCountFieldName(allocator: std.mem.Allocator, member_name: []const u8) ![]const u8 {
    // Reasonable Zig field name for the synthesized count that precedes array pointers.
    // (Field names don't affect ABI for extern structs, but this makes the API pleasant.)
    const singular = blk: {
        if (std.mem.endsWith(u8, member_name, "ies") and member_name.len > 3) {
            break :blk try std.fmt.allocPrint(allocator, "{s}y", .{member_name[0 .. member_name.len - 3]});
        }
        if (std.mem.endsWith(u8, member_name, "s") and member_name.len > 1) {
            break :blk try std.fmt.allocPrint(allocator, "{s}", .{member_name[0 .. member_name.len - 1]});
        }
        break :blk try allocator.dupe(u8, member_name);
    };
    defer allocator.free(singular);
    return std.fmt.allocPrint(allocator, "{s}_count", .{singular});
}

const Casing = enum {
    snake,
    camel,
    pascal,
};

const zig_keywords = std.StaticStringMap(void).initComptime(&.{
    .{ "addrspace", {} },
    .{ "align", {} },
    .{ "allowzero", {} },
    .{ "and", {} },
    .{ "anyframe", {} },
    .{ "anytype", {} },
    .{ "asm", {} },
    .{ "async", {} },
    .{ "await", {} },
    .{ "break", {} },
    .{ "callconv", {} },
    .{ "catch", {} },
    .{ "comptime", {} },
    .{ "const", {} },
    .{ "continue", {} },
    .{ "defer", {} },
    .{ "else", {} },
    .{ "enum", {} },
    .{ "errdefer", {} },
    .{ "error", {} },
    .{ "export", {} },
    .{ "extern", {} },
    .{ "false", {} },
    .{ "fn", {} },
    .{ "for", {} },
    .{ "if", {} },
    .{ "inline", {} },
    .{ "linksection", {} },
    .{ "noalias", {} },
    .{ "noinline", {} },
    .{ "nosuspend", {} },
    .{ "opaque", {} },
    .{ "or", {} },
    .{ "orelse", {} },
    .{ "packed", {} },
    .{ "pub", {} },
    .{ "resume", {} },
    .{ "return", {} },
    .{ "struct", {} },
    .{ "suspend", {} },
    .{ "switch", {} },
    .{ "test", {} },
    .{ "threadlocal", {} },
    .{ "true", {} },
    .{ "try", {} },
    .{ "union", {} },
    .{ "unreachable", {} },
    .{ "usingnamespace", {} },
    .{ "var", {} },
    .{ "volatile", {} },
    .{ "while", {} },
});

fn isIdentStart(c: u8) bool {
    return c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' or c == '_';
}

fn writeIdentifier(w: *std.Io.Writer, str: []const u8, casing: Casing) !void {
    if (str.len == 0) return;
    const escape = zig_keywords.has(str) or !isIdentStart(str[0]);
    if (escape) try w.writeAll("@\"");

    var word_index: usize = 0;
    var in_word_pos: usize = 0;

    var prev: u8 = 0;
    for (str, 0..) |c, i| {
        const next: u8 = if (i + 1 < str.len) str[i + 1] else 0;
        const is_sep = c == '_' or c == '-' or c == ' ';
        if (is_sep) {
            in_word_pos = 0;
            continue;
        }

        const prev_is_lower = prev >= 'a' and prev <= 'z';
        const prev_is_upper = prev >= 'A' and prev <= 'Z';
        const curr_is_upper = c >= 'A' and c <= 'Z';
        const curr_is_lower = c >= 'a' and c <= 'z';
        const next_is_lower = next >= 'a' and next <= 'z';

        const boundary =
            (in_word_pos != 0 and prev_is_lower and curr_is_upper) or
            (in_word_pos != 0 and prev_is_upper and curr_is_upper and next_is_lower);

        if (boundary) {
            in_word_pos = 0;
        }

        if (in_word_pos == 0) {
            if (casing == .snake and word_index != 0) {
                try w.writeByte('_');
            }
            word_index += 1;
        }

        const out_c: u8 = switch (casing) {
            .snake => if (curr_is_upper) std.ascii.toLower(c) else c,
            .camel => blk: {
                if (in_word_pos == 0) {
                    if (word_index == 1) { // first word
                        break :blk if (curr_is_upper) std.ascii.toLower(c) else c;
                    }
                    break :blk if (curr_is_lower) std.ascii.toUpper(c) else c;
                }
                break :blk if (curr_is_upper) std.ascii.toLower(c) else c;
            },
            .pascal => blk: {
                if (in_word_pos == 0) {
                    break :blk if (curr_is_lower) std.ascii.toUpper(c) else c;
                }
                break :blk if (curr_is_upper) std.ascii.toLower(c) else c;
            },
        };

        try w.writeByte(out_c);
        in_word_pos += 1;
        prev = c;
    }

    if (escape) try w.writeByte('"');
}

fn writeWgpuGlobalName(w: *std.Io.Writer, name: []const u8) !void {
    try w.writeAll("wgpu");
    try writeIdentifier(w, name, .pascal);
}

fn writeIndented(
    allocator: std.mem.Allocator,
    w: *std.Io.Writer,
    comptime indent_char: u8,
    indent_level: usize,
    comptime fmt: []const u8,
    args: anytype,
    comptime line_fmt: []const u8,
) !void {
    const formatted = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(formatted);

    var lines = std.mem.splitScalar(u8, formatted, '\n');
    while (lines.next()) |line| {
        try w.splatByteAll(indent_char, indent_level);
        try w.print(line_fmt, .{line});
        try w.writeByte('\n');
    }
}

fn writeValue64(w: *std.Io.Writer, v: Schema.Value64) !void {
    try switch (v) {
        .number => |n| w.print("{d}", .{n}),
        .usize_max => w.writeAll("std.math.maxInt(usize)"),
        .uint32_max => w.writeAll("std.math.maxInt(u32)"),
        .uint64_max => w.writeAll("std.math.maxInt(u64)"),
        .nan => w.writeAll("std.math.nan(f32)"),
    };
}

pub fn main() !void {
    var gpa_state: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var iot = std.Io.Threaded.init(gpa);
    defer iot.deinit();
    const io = iot.io();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.skip();

    const webgpu_json_contents = blk: {
        const input_path = args.next() orelse {
            std.log.err("No input file specified", .{});
            return;
        };

        const input_file = if (std.mem.eql(u8, input_path, "-"))
            std.Io.File.stdin()
        else
            try std.Io.Dir.cwd().openFile(io, input_path, .{});
        defer input_file.close(io);

        const contents = try readFile(io, gpa, input_file);
        break :blk contents;
    };

    defer gpa.free(webgpu_json_contents);

    const output_file = blk: {
        const output_path = args.next() orelse {
            std.log.err("No output file specified", .{});
            return;
        };

        if (std.mem.eql(u8, output_path, "-")) {
            break :blk std.Io.File.stdout();
        }

        if (std.fs.path.dirname(output_path)) |dir| {
            try std.Io.Dir.cwd().makePath(io, dir);
        }

        const output_file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
        break :blk output_file;
    };
    defer output_file.close(io);
    var out_buf: [1024 * 1024]u8 = undefined;
    var out_writer = (std.fs.File{ .handle = output_file.handle }).writer(&out_buf);

    try gen(gpa, webgpu_json_contents, &out_writer.interface);
    try out_writer.interface.flush();
}

fn readFile(io: std.Io, allocator: std.mem.Allocator, file: std.Io.File) ![]const u8 {
    var read_buf: [1024 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &read_buf);
    var w = std.Io.Writer.Allocating.init(allocator);
    errdefer w.deinit();
    _ = try file_reader.interface.streamRemaining(&w.writer);
    return w.toOwnedSlice();
}
