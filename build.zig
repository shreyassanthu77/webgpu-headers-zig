const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const webgpu_headers_dep = b.dependency("webgpu_headers", .{});
    const webgpu_headers_json = webgpu_headers_dep.path("webgpu.json");

    const gen = b.addExecutable(.{
        .name = "gen-bindings",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen.zig"),
            .target = b.graph.host,
        }),
    });

    const run_gen = b.addRunArtifact(gen);
    run_gen.addFileArg(webgpu_headers_json);
    const output_file = run_gen.addOutputFileArg("bindings.zig");
    b.getInstallStep().dependOn(&run_gen.step);
    _ = b.addModule("webgpu", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = output_file,
    });

    const write_step = b.step("write", "Writes the bindings to the build directory");
    const temp_out = b.addInstallFile(output_file, "./bindings.zig");
    write_step.dependOn(&temp_out.step);

    const test_step = b.step("test", "Runs the tests");
    const test_prelude = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prelude.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_test_prelude = b.addRunArtifact(test_prelude);
    test_step.dependOn(&run_test_prelude.step);
}
