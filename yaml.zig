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
    _ = allocator;
    while (try self.nextEvent()) {
        log.info("{s}", .{eventTypeString(self.event)});
    }

    const result = T{};

    return result;
}

fn nextEvent(self: *Yaml) !bool {
    if (!self.first) {
        c.yaml_event_delete(&self.event);
    } else {
        self.first = false;
    }
    const res = c.yaml_parser_parse(&self.parser, &self.event);
    if (res == 0) return false;
    return self.event.type != c.YAML_NO_EVENT;
    // if (c.yaml_parser_parse(&self.parser, &self.event) == 0) {
    //     return error.ParserError;
    // }
    // return self.event.type != c.YAML_NO_EVENT;
}

fn eventTypeString(event: c.yaml_event_t) []const u8 {
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
