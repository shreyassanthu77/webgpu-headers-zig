const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.@"webgpu-zig-bindgen");

fn generateBindings(gpa: std.mem.Allocator, input_contents: []const u8, writer: *std.Io.Writer) !void {
    _ = gpa;
    log.info("Input contents:\n{s}", .{input_contents});
    try writer.writeAll(
        \\const std = @import("std");
        \\
    );
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

pub const main = switch (builtin.zig_version.minor) {
    0...14 => @compileError("At least Zig 0.15 is required"),
    15 => lessJuicyMain,
    else => juicyMain,
};
