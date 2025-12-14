const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    // const target = b.standardTargetOptions(.{});

    const webgpu_headers_dep = b.dependency("webgpu_headers", .{});
    const webgpu_headers_json = webgpu_headers_dep.path("webgpu.json");

    const gen = b.addExecutable(.{
        .name = "Generate Zig bindings",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });

    const run_gen = b.addRunArtifact(gen);
    run_gen.addFileArg(webgpu_headers_json);
    run_gen.addArg(try b.build_root.join(b.allocator, &.{ "src", "bindings.zig" }));
    if (b.args) |args| {
        run_gen.addArgs(args);
    }
    const run_gen_step = b.step("gen", "Generate Zig bindings");
    run_gen_step.dependOn(&run_gen.step);
}
