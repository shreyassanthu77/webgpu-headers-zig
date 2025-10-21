const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const use_llvm = b.option(bool, "use_llvm", "Use llvm for the bindings generator") orelse false;
    // const webgpu_headers_yaml = b.option(std.Build.LazyPath, "webgpu_headers_yaml", "Path to the webgpu-headers.yaml file") orelse
    //     getBundledWebgpuHeadersYaml(b);

    const bindings_generator = b.addExecutable(.{
        .name = "wgpu-zig-bindings-generator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("gen.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = use_llvm,
    });
    bindings_generator.linkSystemLibrary("fyaml");
    bindings_generator.linkLibC();
    b.installArtifact(bindings_generator);

    const run_bindings_generator = b.addRunArtifact(bindings_generator);
    if (b.args) |args| {
        run_bindings_generator.addArgs(args);
    }
    const run_bindings_gen_step = b.step("gen", "Run bindings generator");
    run_bindings_gen_step.dependOn(&run_bindings_generator.step);

    // run_bindings_generator.addFileArg(webgpu_headers_yaml);
    // const bindings_output_path = run_bindings_generator.addOutputFileArg("wgpu.zig");
    //
    // b.getInstallStep().dependOn(&b.addInstallFile(bindings_output_path, "wgpu.zig").step);
}

fn getBundledWebgpuHeadersYaml(b: *std.Build) std.Build.LazyPath {
    const webgpu_headers_dep = b.dependency("webgpu_headers", .{});
    const webgpu_headers_yaml = webgpu_headers_dep.path("webgpu.yml");
    return webgpu_headers_yaml;
}
