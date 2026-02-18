const std = @import("std");
const wgpu = @import("bindings");

const c = @cImport({
    @cInclude("webgpu.h");
});

fn cNameFor(comptime zig_name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, zig_name, "Bool")) return "WGPUBool";
    if (std.mem.eql(u8, zig_name, "String")) return "WGPUStringView";
    return std.fmt.comptimePrint("WGPU{s}", .{zig_name});
}

fn isPackedBitflagStruct(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| s.layout == .@"packed",
        else => false,
    };
}

fn isOptionalPointer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => |o| switch (@typeInfo(o.child)) {
            .pointer => true,
            else => false,
        },
        else => false,
    };
}

fn comptimeFail(comptime name: []const u8, comptime what: []const u8) noreturn {
    @compileError(std.fmt.comptimePrint("ABI/API mismatch for {s}: {s}", .{ name, what }));
}

fn expectTypeAbiCompatible(comptime name: []const u8, comptime Z: type, comptime C: type) void {
    if (@sizeOf(C) != @sizeOf(Z)) comptimeFail(name, "size");
    if (@alignOf(C) != @alignOf(Z)) comptimeFail(name, "align");

    const zi = @typeInfo(Z);
    const ci = @typeInfo(C);

    const zi_tag = std.meta.activeTag(zi);
    const ci_tag = std.meta.activeTag(ci);
    if (zi_tag != ci_tag) {
        // C bitflags are integer aliases; Zig bitflags are packed struct(u32/u64).
        if (zi_tag == .@"struct" and ci_tag == .int and isPackedBitflagStruct(Z)) return;
        // Many C enums import as integer aliases through @cImport.
        if (zi_tag == .@"enum" and ci_tag == .int) return;
        // C function-pointer typedefs often import as optional pointers.
        if (zi_tag == .pointer and isOptionalPointer(C)) return;
        if (ci_tag == .pointer and isOptionalPointer(Z)) return;
        comptimeFail(name, "type kind");
    }

    switch (zi) {
        .@"struct" => |zs| {
            const cs = switch (ci) {
                .@"struct" => |v| v,
                else => unreachable,
            };
            if (cs.layout != zs.layout) comptimeFail(name, "struct layout");
            if (cs.fields.len != zs.fields.len) comptimeFail(name, "struct field count");
            inline for (zs.fields, 0..) |zf, i| {
                const cf = cs.fields[i];
                if (@offsetOf(Z, zf.name) != @offsetOf(C, cf.name)) comptimeFail(name, "field offset");
                if (@sizeOf(cf.type) != @sizeOf(zf.type)) comptimeFail(name, "field size");
                if (@alignOf(cf.type) != @alignOf(zf.type)) comptimeFail(name, "field align");
            }
        },
        .@"enum" => |ze| {
            const ce = switch (ci) {
                .@"enum" => |v| v,
                else => unreachable,
            };
            if (@sizeOf(ce.tag_type) != @sizeOf(ze.tag_type)) comptimeFail(name, "enum tag size");

            const c_has_force32 = ce.fields.len > 0 and std.mem.endsWith(u8, ce.fields[ce.fields.len - 1].name, "Force32");
            const c_len_without_force32 = if (c_has_force32) ce.fields.len - 1 else ce.fields.len;
            if (c_len_without_force32 != ze.fields.len) comptimeFail(name, "enum field count");

            inline for (ze.fields, 0..) |zf, i| {
                const cf = ce.fields[i];
                if (cf.value != zf.value) comptimeFail(name, "enum field value");
            }
        },
        .pointer => {
            // Size/alignment check above is enough for ABI check here.
        },
        .optional => {
            // Size/alignment check above is enough for ABI check here.
        },
        .int => {
            // Size/alignment check above is enough for ABI check here.
        },
        else => {
            @compileError(std.fmt.comptimePrint("Unhandled type kind '{s}' for {s}", .{ @tagName(zi_tag), name }));
        },
    }
}

test "bindings types are API/ABI compatible with webgpu.h" {
    @setEvalBranchQuota(300000);

    comptime {
        // Explicitly check Optional bool mapping, which is nested under Bool.
        expectTypeAbiCompatible("WGPUOptionalBool", wgpu.Bool.Optional, c.WGPUOptionalBool);

        const decls = std.meta.declarations(wgpu);
        for (decls) |decl| {
            const value = @field(wgpu, decl.name);
            if (@TypeOf(value) != type) continue;

            const c_name_opt = cNameFor(decl.name);
            if (c_name_opt) |c_name| {
                if (@hasDecl(c, c_name)) {
                    const Z = value;
                    const C = @field(c, c_name);
                    expectTypeAbiCompatible(c_name, Z, C);
                }
            }
        }

        if (c.WGPU_ARRAY_LAYER_COUNT_UNDEFINED != wgpu.array_layer_count_undefined) comptimeFail("WGPU_ARRAY_LAYER_COUNT_UNDEFINED", "constant");
        if (c.WGPU_COPY_STRIDE_UNDEFINED != wgpu.copy_stride_undefined) comptimeFail("WGPU_COPY_STRIDE_UNDEFINED", "constant");
        const c_depth_clear_bits: u32 = @bitCast(@as(f32, c.WGPU_DEPTH_CLEAR_VALUE_UNDEFINED));
        const z_depth_clear_bits: u32 = @bitCast(@as(f32, wgpu.depth_clear_value_undefined));
        if (c_depth_clear_bits != z_depth_clear_bits) comptimeFail("WGPU_DEPTH_CLEAR_VALUE_UNDEFINED", "constant bits");
        if (c.WGPU_DEPTH_SLICE_UNDEFINED != wgpu.depth_slice_undefined) comptimeFail("WGPU_DEPTH_SLICE_UNDEFINED", "constant");
        if (c.WGPU_LIMIT_U32_UNDEFINED != wgpu.limit_u32_undefined) comptimeFail("WGPU_LIMIT_U32_UNDEFINED", "constant");
        if (c.WGPU_LIMIT_U64_UNDEFINED != wgpu.limit_u64_undefined) comptimeFail("WGPU_LIMIT_U64_UNDEFINED", "constant");
        if (c.WGPU_MIP_LEVEL_COUNT_UNDEFINED != wgpu.mip_level_count_undefined) comptimeFail("WGPU_MIP_LEVEL_COUNT_UNDEFINED", "constant");
        if (c.WGPU_QUERY_SET_INDEX_UNDEFINED != wgpu.query_set_index_undefined) comptimeFail("WGPU_QUERY_SET_INDEX_UNDEFINED", "constant");
        if (c.WGPU_STRLEN != wgpu.strlen) comptimeFail("WGPU_STRLEN", "constant");
        if (c.WGPU_WHOLE_MAP_SIZE != wgpu.whole_map_size) comptimeFail("WGPU_WHOLE_MAP_SIZE", "constant");
        if (c.WGPU_WHOLE_SIZE != wgpu.whole_size) comptimeFail("WGPU_WHOLE_SIZE", "constant");
    }
}
