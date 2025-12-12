const std = @import("std");
const Schema = @import("schema.zig");

const prelude =
    \\const std = @import("std");
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
        try w.print("pub const {s} = enum(u32) {{\n", .{bitflag_name});
        try writeIndented(
            alloc,
            w,
            ' ',
            4,
            \\/// This function allows you to set multiple flags at once.
            \\/// Example:
            \\/// ```zig
            \\/// const flags: {s} = .all(.{{ .a, .b }});
            \\/// ```
            \\pub fn all(values: []const @This()) @This() {{
            \\    var result: u32 = 0;
            \\    for (values) |value| {{
            \\        result |= @intFromEnum(value);
            \\    }}
            \\    return @enumFromInt(result);
            \\}}
            \\
            \\/// This function allows you to set multiple flags at once.
            \\/// Example:
            \\/// ```zig
            \\/// const flags: {s} = .a.plus(.b).plus(.c);
            \\///```
            \\pub fn plus(lhs: @This(), rhs: @This()) @This() {{
            \\    return @enumFromInt(@intFromEnum(lhs) & @intFromEnum(rhs));
            \\}}
        ,
            .{ bitflag_name, bitflag_name },
            "{s}",
        );
        try w.writeAll("};\n\n");
    }
}

const Casing = enum {
    snake,
    camel,
    pascal,
};
const special_vars = std.StaticStringMap(void).initComptime(&.{
    .{"undefined"},
    .{"error"},
    .{"opaque"},
});
fn isIdentStart(c: u8) bool {
    return c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' or c == '_';
}

fn writeIdentifier(w: *std.Io.Writer, str: []const u8, comptime casing: Casing) !void {
    if (str.len == 0) return;
    var capitalize = casing == .pascal;
    const escape = special_vars.has(str) or !isIdentStart(str[0]);
    if (escape) try w.writeAll("@\"");

    for (str) |c| {
        if (c == '_' or c == '-' or c == ' ') {
            switch (casing) {
                .snake => {},
                .camel, .pascal => {
                    capitalize = true;
                    continue;
                },
            }
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
        .nan => w.writeAll("std.zig.c_translation.builtins.nanf(\"\")"),
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
