const std = @import("std");
const Schema = @import("schema.zig");

const prelude =
    \\const std = @import("std");
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
    \\    next: *const Chained,
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

    for (content.structs) |s| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{s.doc}, "{s}");
        try w.writeAll("pub const ");
        try writeIdentifier(w, s.name, .pascal);
        try w.writeAll(" = extern struct {\n");
        for (s.members) |member| {
            try writeIndented(alloc, w, ' ', 4, "{s}", .{member.doc}, "/// {s}");
            try w.splatByteAll(' ', 4);
            try writeIdentifier(w, member.name, .snake);
            try w.print(": ", .{});
            try writeParam(w, member);
            try w.writeAll(",\n");
        }
        try w.writeAll("};\n\n");
    }

    for (content.objects) |object| {
        try writeIndented(alloc, w, '/', 3, "{s}", .{object.doc}, "{s}");
        try w.writeAll("pub const ");
        try writeIdentifier(w, object.name, .pascal);
        try w.writeAll(" = *opaque {\n");
        try w.writeAll("};\n\n");
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
fn writeParam(w: *std.Io.Writer, p: Schema.Function.Parameter) !void {
    const opt = if (p.optional != null and p.optional.? == true) "?" else "";
    const ptr = if (p.pointer) |ptr| switch (ptr) {
        .immutable => "*const ",
        .mutable => "* ",
    } else "";
    var is_array = false;
    var casing: Casing = .snake;
    const resolved = primitive_types.get(p.type) orelse blk: {
        if (std.mem.startsWith(u8, p.type, "array<")) {
            is_array = true;
        }
        const maybe_array = if (is_array)
            p.type[6 .. p.type.len - 1]
        else
            p.type;
        inline for ([_][]const u8{
            "typedef.",
            "enum.",
            "bitflag.",
            "struct.",
            // "function_type.",
            "object.",
        }) |prefix| {
            if (std.mem.startsWith(u8, maybe_array, prefix)) {
                casing = .pascal;
                break :blk maybe_array[prefix.len..];
            }
        }
        break :blk maybe_array;
    };
    try w.print("{s}{s}", .{ ptr, opt });
    try writeIdentifier(w, resolved, casing);
}

const Casing = enum {
    snake,
    camel,
    pascal,
};
const special_vars = std.StaticStringMap(void).initComptime(&.{
    .{"error"},
    .{"opaque"},
});
fn isIdentStart(c: u8) bool {
    return c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' or c == '_';
}

fn writeIdentifier(w: *std.Io.Writer, str: []const u8, casing: Casing) !void {
    if (str.len == 0) return;
    var capitalize = casing == .pascal;
    const escape = special_vars.has(str) or !isIdentStart(str[0]);
    if (escape) try w.writeAll("@\"");

    var prev_char: u8 = 0;
    for (str) |c| {
        defer prev_char = c;
        const is_prev_lower = prev_char >= 'a' and prev_char <= 'z';
        const is_curr_upper = c >= 'A' and c <= 'Z';
        const is_case_change = is_prev_lower and is_curr_upper;

        if (c == '_' or c == '-' or c == ' ' or is_case_change) {
            const sep = switch (casing) {
                .snake => '_',
                .camel, .pascal => {
                    capitalize = true;
                    continue;
                },
            };
            try w.writeByte(sep);
            continue;
        }
        if (capitalize) {
            try w.writeByte(std.ascii.toUpper(c));
            capitalize = false;
        } else {
            try w.writeByte(c);
        }
    }

    if (escape) try w.writeByte('"');
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
