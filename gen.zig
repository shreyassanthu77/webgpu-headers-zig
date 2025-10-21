const std = @import("std");
const log = std.log.scoped(.gen_zig_bindings);
const c = @cImport({
    @cInclude("libfyaml.h");
});

pub fn main() !void {
    var gpa_state: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    _ = args.skip(); // program name

    const wgpu_headers_yaml_path = args.next() orelse {
        std.log.err("No webgpu-headers.yaml file specified", .{});
        return;
    };

    // const output_file_path = args.next() orelse {
    //     std.log.err("No output file specified", .{});
    //     return;
    // };
    // const output_file = if (std.mem.eql(u8, output_file_path, "-"))
    //     std.fs.File.stdout()
    // else
    //     try std.fs.cwd().createFile(output_file_path, .{});
    //
    // defer output_file.close();
    // var write_buffer: [1024 * 1024]u8 = undefined;
    // var file_writer = output_file.writer(&write_buffer);
    // var writer = &file_writer.interface;

    log.info("Reading {s}", .{wgpu_headers_yaml_path});
    const wgpu_headers_yaml = try std.fs.cwd().readFileAlloc(wgpu_headers_yaml_path, gpa, .unlimited);
    defer gpa.free(wgpu_headers_yaml);

    // Parse YAML using libfyaml
    const doc = c.fy_document_create(null);
    defer c.fy_document_destroy(doc);

    const parse_result = c.fy_document_build_from_string(null, wgpu_headers_yaml.ptr, wgpu_headers_yaml.len);
    if (parse_result == null) {
        log.err("Failed to parse YAML", .{});
        return error.ParseError;
    }

    const root = c.fy_document_root(doc);

    // Try to get copyright field - try different API approaches
    const copyright_node = c.fy_node_lookup(root, "copyright");
    if (copyright_node != null) {
        const copyright_str = c.fy_node_get_scalar(copyright_node);
        if (copyright_str != null) {
            const copyright_len = c.fy_node_get_scalar_len(copyright_node);
            const copyright_value = copyright_str[0..copyright_len];
            log.info("copyright `{s}`", .{copyright_value});
        } else {
            log.info("copyright node is not a scalar", .{});
        }
    } else {
        log.info("copyright field not found", .{});
    }

    // var parser = try YamlParser.init(wgpu_headers_yaml);
    // defer parser.deinit();
    // const res = try parser.parseDocument(struct {
    //     copyright: []const u8,
    //     name: []const u8,
}
