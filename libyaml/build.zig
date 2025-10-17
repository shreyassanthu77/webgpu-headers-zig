const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("libyaml", .{});

    const libyaml = b.addLibrary(.{
        .name = "yaml",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    const src_root = upstream.path("src");
    const include_root = upstream.path("include");

    libyaml.root_module.link_libc = true;
    libyaml.root_module.addIncludePath(include_root);
    libyaml.root_module.addIncludePath(src_root);
    libyaml.root_module.addCSourceFiles(.{
        .root = src_root,
        .files = sources,
        .flags = &.{},
    });
    libyaml.root_module.addCMacro("YAML_VERSION_MAJOR", "0");
    libyaml.root_module.addCMacro("YAML_VERSION_MINOR", "2");
    libyaml.root_module.addCMacro("YAML_VERSION_PATCH", "5");
    libyaml.root_module.addCMacro("YAML_VERSION_STRING", "\"0.2.5\"");
    libyaml.installHeader(upstream.path("include/yaml.h"), "yaml.h");
    b.installArtifact(libyaml);
}

const sources: []const []const u8 = &.{
    "api.c",
    "dumper.c",
    "emitter.c",
    "loader.c",
    "parser.c",
    "reader.c",
    "scanner.c",
    "writer.c",
};
