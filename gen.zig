const std = @import("std");
const log = std.log.scoped(.gen_zig_bindings);
const Yaml = @import("yaml.zig");

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
    const wgpu_headers_yaml = try std.fs.cwd().readFileAlloc(gpa, wgpu_headers_yaml_path, std.math.maxInt(usize));
    defer gpa.free(wgpu_headers_yaml);

    var yaml = try Yaml.init(wgpu_headers_yaml);
    defer yaml.deinit();

    const res = try yaml.parseDocument(struct {
        copyright: ?[]const u8 = null,
    }, gpa);
    defer res.deinit();
    log.info("copyright `{?s}`", .{res.value.copyright});

    // var parser = try YamlParser.init(wgpu_headers_yaml);
    // defer parser.deinit();
    // const res = try parser.parseDocument(struct {
    //     copyright: []const u8,
    //     name: []const u8,
    // }, gpa);
    // defer res.deinit();
    // const name = res.value.name;
    // const copyright = res.value.copyright;
    // log.info("{s} {s}", .{ name, copyright });
    // // try writer.flush();
}

pub const YamlParser = struct {
    const c = @cImport({
        @cInclude("yaml.h");
    });

    parser: c.yaml_parser_t,

    pub fn init(src: []const u8) !YamlParser {
        var parser: c.yaml_parser_t = undefined;
        if (c.yaml_parser_initialize(&parser) != 1) {
            log.err("Failed to initialize parser", .{});
            return error.ParserError;
        }
        c.yaml_parser_set_input_string(
            &parser,
            src.ptr,
            src.len,
        );

        var event: c.yaml_event_t = undefined;
        {
            if (c.yaml_parser_parse(&parser, &event) == 0) {
                return error.ParserError;
            }
            defer c.yaml_event_delete(&event);
            switch (event.type) {
                c.YAML_STREAM_START_EVENT => {},
                else => return error.ParserError,
            }
        }

        return .{
            .parser = parser,
        };
    }

    pub fn deinit(self: *YamlParser) void {
        c.yaml_parser_delete(&self.parser);
    }

    pub fn parseDocument(self: *YamlParser, comptime T: type, allocator: std.mem.Allocator) !Parsed(T) {
        var event: c.yaml_event_t = undefined;
        if (!try self.nextEvent(&event)) return error.UnexpectedEndOfInput;

        switch (event.type) {
            c.YAML_DOCUMENT_START_EVENT => {},
            else => return error.ExpectedDocumentStart,
        }
        c.yaml_event_delete(&event);

        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        if (!try self.nextEvent(&event)) return error.UnexpectedEndOfInput;
        const parsed = try self.parseEvent(T, arena.allocator(), &event);
        c.yaml_event_delete(&event);

        if (try self.nextEvent(&event)) {
            defer c.yaml_event_delete(&event);
            switch (event.type) {
                c.YAML_DOCUMENT_END_EVENT => {},
                else => return error.ExpectedDocumentEnd,
            }
        }

        return .{
            .arena = arena,
            .value = parsed,
        };
    }

    fn parseEvent(self: *YamlParser, comptime T: type, allocator: std.mem.Allocator, event: *c.yaml_event_t) !T {
        const info = @typeInfo(T);
        switch (info) {
            .int => {
                defer c.yaml_event_delete(event);
                switch (event.type) {
                    c.YAML_SCALAR_EVENT => {
                        const scalar = event.data.scalar;
                        const value = scalar.value[0..scalar.length];
                        const result = try std.fmt.parseInt(T, value, 10);
                        return result;
                    },
                    else => return error.UnexpectedToken,
                }
            },
            .float => {
                defer c.yaml_event_delete(event);
                switch (event.type) {
                    c.YAML_SCALAR_EVENT => {
                        const scalar = event.data.scalar;
                        const value = scalar.value[0..scalar.length];
                        const result = try std.fmt.parseFloat(T, value);
                        return result;
                    },
                    else => return error.UnexpectedToken,
                }
            },
            .bool => {
                defer c.yaml_event_delete(event);
                switch (event.type) {
                    c.YAML_SCALAR_EVENT => {
                        const scalar = event.data.scalar;
                        const value = scalar.value[0..scalar.length];
                        if (std.mem.eql(u8, value, "true")) {
                            return true;
                        } else if (std.mem.eql(u8, value, "false")) {
                            return false;
                        } else {
                            return error.ExpectedBool;
                        }
                    },
                    else => return error.UnexpectedToken,
                }
            },
            .@"struct" => |struct_info| {
                switch (event.type) {
                    c.YAML_MAPPING_START_EVENT => {},
                    else => return error.UnexpectedToken,
                }
                c.yaml_event_delete(event);

                const fields = struct_info.fields;
                var result: T = undefined;
                var found: [fields.len]bool = [_]bool{false} ** fields.len;
                while (true) {
                    if (!try self.nextEvent(event)) break;

                    const key = switch (event.type) {
                        c.YAML_MAPPING_END_EVENT => {
                            c.yaml_event_delete(event);
                            break;
                        },
                        c.YAML_SCALAR_EVENT => blk: {
                            const scalar = event.data.scalar;
                            const value = scalar.value[0..scalar.length];
                            break :blk value;
                        },
                        else => return error.UnexpectedToken,
                    };

                    inline for (fields, 0..) |field, i| {
                        if (field.is_comptime) @compileError("comptime fields are not supported: " ++ @typeName(T) ++ "." ++ field.name);
                        if (std.mem.eql(u8, field.name, key)) {
                            c.yaml_event_delete(event); // free the key event
                            if (found[i]) return error.DuplicateField;

                            if (!try self.nextEvent(event)) return error.UnexpectedEndOfInput;
                            @field(result, field.name) = try self.parseEvent(field.type, allocator, event);
                            found[i] = true;
                            break;
                        }
                    } else {
                        // Didn't match anything.
                        c.yaml_event_delete(event);
                    }
                }

                inline for (fields, 0..) |field, i| {
                    if (!found[i]) {
                        if (field.defaultValue()) |default| {
                            @field(result, field.name) = default;
                        } else {
                            return error.MissingField;
                        }
                    }
                }

                return result;
            },
            .pointer => |ptr_info| {
                switch (ptr_info.size) {
                    .one => {
                        const ptr = try allocator.create(ptr_info.child);
                        errdefer allocator.destroy(ptr);
                        ptr.* = try self.parseEvent(ptr_info.child, allocator, event);
                        return ptr;
                    },
                    .slice => {
                        switch (event.type) {
                            c.YAML_SEQUENCE_START_EVENT => {
                                c.yaml_event_delete(event);

                                var array_list: std.ArrayList(ptr_info.child) = .empty;
                                errdefer array_list.deinit(allocator);
                                while (true) {
                                    if (!try self.nextEvent(event)) break;
                                    switch (event.type) {
                                        c.YAML_SEQUENCE_END_EVENT => {
                                            c.yaml_event_delete(event);
                                            break;
                                        },
                                        else => {
                                            try array_list.ensureUnusedCapacity(allocator, 1);
                                            array_list.appendAssumeCapacity(try self.parseEvent(ptr_info.child, allocator, event));
                                        },
                                    }
                                }

                                if (ptr_info.sentinel()) |sentinel| {
                                    return try array_list.toOwnedSliceSentinel(allocator, sentinel);
                                }

                                return try array_list.toOwnedSlice(allocator);
                            },
                            c.YAML_SCALAR_EVENT => {
                                if (ptr_info.child != u8) return error.UnexpectedToken;
                                const slice = event.data.scalar.value[0..event.data.scalar.length];
                                var copy: std.ArrayList(u8) = .empty;
                                errdefer copy.deinit(allocator);
                                try copy.appendSlice(allocator, slice);
                                c.yaml_event_delete(event);

                                if (ptr_info.sentinel()) |sentinel| {
                                    return try copy.toOwnedSliceSentinel(allocator, sentinel);
                                }

                                return try copy.toOwnedSlice(allocator);
                            },
                            else => return error.UnexpectedToken,
                        }
                    },
                    else => @compileError("cannot parse into [*]... or [*c]..."),
                }
            },
            else => @compileError("TODO"),
        }
    }

    fn nextEvent(self: *YamlParser, event: *c.yaml_event_t) !bool {
        const res = c.yaml_parser_parse(&self.parser, event);
        if (res == 0) return false;
        return event.type != c.YAML_NO_EVENT;
    }

    pub fn Parsed(comptime T: type) type {
        return struct {
            const Self = @This();

            arena: *std.heap.ArenaAllocator,
            value: T,

            pub fn deinit(self: Self) void {
                const allocator = self.arena.child_allocator;
                self.arena.deinit();
                allocator.destroy(self.arena);
            }
        };
    }

    fn getEventTypeString(event: c.yaml_event_t) []const u8 {
        return switch (event.type) {
            c.YAML_NO_EVENT => "no event",
            c.YAML_STREAM_START_EVENT => "stream start",
            c.YAML_STREAM_END_EVENT => "stream end",
            c.YAML_DOCUMENT_START_EVENT => "document start",
            c.YAML_DOCUMENT_END_EVENT => "document end",
            c.YAML_ALIAS_EVENT => "alias",
            c.YAML_SCALAR_EVENT => "scalar",
            c.YAML_SEQUENCE_START_EVENT => "sequence start",
            c.YAML_SEQUENCE_END_EVENT => "sequence end",
            c.YAML_MAPPING_START_EVENT => "mapping start",
            c.YAML_MAPPING_END_EVENT => "mapping end",
            else => "unknown",
        };
    }
};
