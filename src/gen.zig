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
            if (entry.value) |value| {
                log.info("        {s}", .{value});
            }
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

pub const main = switch (builtin.zig_version.major) {
    0 => switch (builtin.zig_version.minor) {
        0...14 => @compileError("At least Zig 0.15 is required"),
        15 => lessJuicyMain,
        else => juicyMain,
    },
    else => @compileError("lol"),
};
