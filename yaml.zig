const std = @import("std");
const log = std.log.scoped(.yaml);
const c = @cImport({
    @cInclude("yaml.h");
});

const Yaml = @This();

parser: c.yaml_parser_t,
event: c.yaml_event_t = undefined,
first: bool = true,

pub fn init(src: []const u8) !Yaml {
    var parser: c.yaml_parser_t = undefined;
    if (c.yaml_parser_initialize(&parser) != 1) {
        return error.ParserInitFailed;
    }
    errdefer c.yaml_parser_delete(&parser);
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

pub fn deinit(self: *Yaml) void {
    c.yaml_parser_delete(&self.parser);
}

pub fn parseDocument(self: *Yaml, comptime T: type, gpa: std.mem.Allocator) !Parsed(T) {
    if (try self.nextEvent()) {
        if (self.event.type != c.YAML_DOCUMENT_START_EVENT) {
            return error.ExpectedDocumentStart;
        }
    }

    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();

    const res = try self.parse(T, arena.allocator());
    return Parsed(T){
        .arena = arena,
        .value = res,
    };
}

fn parse(self: *Yaml, comptime T: type, allocator: std.mem.Allocator) !T {
    const t_info = @typeInfo(T);
    switch (t_info) {
        .int => {
            if (!try self.nextEvent()) return error.UnexpectedEndOfInput;
            switch (self.event.type) {
                c.YAML_SCALAR_EVENT => {
                    const scalar = self.event.data.scalar;
                    const value = scalar.value[0..scalar.length];
                    const result = try std.fmt.parseInt(T, value, 10);
                    return result;
                },
                else => return error.UnexpectedToken,
            }
        },
        .float => {
            if (!try self.nextEvent()) return error.UnexpectedEndOfInput;
            switch (self.event.type) {
                c.YAML_SCALAR_EVENT => {
                    const scalar = self.event.data.scalar;
                    const value = scalar.value[0..scalar.length];
                    const result = try std.fmt.parseFloat(T, value);
                    return result;
                },
                else => return error.UnexpectedToken,
            }
        },
        .bool => {
            if (!try self.nextEvent()) return error.UnexpectedEndOfInput;
            switch (self.event.type) {
                c.YAML_SCALAR_EVENT => {
                    const scalar = self.event.data.scalar;
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
            if (!try self.nextEvent()) return error.UnexpectedEndOfInput;
            switch (self.event.type) {
                c.YAML_MAPPING_START_EVENT => {},
                else => return error.UnexpectedToken,
            }

            const fields = struct_info.fields;
            var result: T = undefined;
            var found: [fields.len]bool = [_]bool{false} ** fields.len;
            while (true) {
                if (!try self.nextEvent()) break;

                const key = switch (self.event.type) {
                    c.YAML_MAPPING_END_EVENT => break,
                    c.YAML_SCALAR_EVENT => blk: {
                        const scalar = self.event.data.scalar;
                        const value = scalar.value[0..scalar.length];
                        break :blk value;
                    },
                    else => return error.UnexpectedToken,
                };

                inline for (fields, 0..) |field, i| {
                    if (field.is_comptime) @compileError("comptime fields are not supported: " ++ @typeName(T) ++ "." ++ field.name);
                    if (std.mem.eql(u8, field.name, key)) {
                        if (found[i]) return error.DuplicateField;

                        if (!try self.nextEvent()) return error.UnexpectedEndOfInput;
                        @field(result, field.name) = try self.parse(field.type, allocator);
                        found[i] = true;
                        break;
                    }
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
                    ptr.* = try self.parse(ptr_info.child, allocator);
                    return ptr;
                },
                .slice => {
                    switch (self.event.type) {
                        c.YAML_SEQUENCE_START_EVENT => {
                            var array_list: std.ArrayList(ptr_info.child) = .empty;
                            errdefer array_list.deinit(allocator);

                            while (true) {
                                if (!try self.nextEvent()) break;
                                switch (self.event.type) {
                                    c.YAML_SEQUENCE_END_EVENT => break,
                                    else => {
                                        try array_list.ensureUnusedCapacity(allocator, 1);
                                        array_list.appendAssumeCapacity(try self.parse(ptr_info.child, allocator));
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
                            const slice = self.event.data.scalar.value[0..self.event.data.scalar.length];
                            var copy: std.ArrayList(u8) = .empty;
                            errdefer copy.deinit(allocator);
                            try copy.appendSlice(allocator, slice);

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
        else => @compileError(std.fmt.comptimePrint("TODO: {s}", .{@typeName(T)})),
    }
}

fn nextEvent(self: *Yaml) !bool {
    if (self.first) {
        self.first = false;
    } else {
        c.yaml_event_delete(&self.event);
    }
    if (c.yaml_parser_parse(&self.parser, &self.event) == 0) {
        log.info("event `{s}`", .{eventTypeString(&self.event)});
        return error.ParserError;
    }
    log.info("event `{s}`", .{eventTypeString(&self.event)});
    return self.event.type != c.YAML_NO_EVENT;
}

fn eventTypeString(event: *const c.yaml_event_t) []const u8 {
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

pub fn Parsed(comptime T: type) type {
    return struct {
        const Self = @This();

        arena: std.heap.ArenaAllocator,
        value: T,

        pub fn deinit(self: Self) void {
            self.arena.deinit();
        }
    };
}
