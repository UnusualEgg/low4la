const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const optimize = b.standardOptimizeOption(std.Build.StandardOptimizeOptionOptions{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const lola_dep = b.dependency("lola", .{
        .target = target,
        .optimize = optimize,
    });
    const lola = lola_dep.module("lola");
    lola.optimize = optimize;
    lola.resolved_target = target;

    const wasm4_mod = b.createModule(.{
        .root_source_file = b.path("src/wasm4.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
        .single_threaded = true,
    });
    const salloc_dep = b.dependency("staticalloc", .{ .target = target, .optimize = optimize });
    const salloc_mod = salloc_dep.module("staticalloc");
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
        .single_threaded = true,
        .error_tracing = true,
    });
    exe_mod.addImport("lola", lola);
    exe_mod.addImport("wasm4", wasm4_mod);
    exe_mod.addImport("salloc", salloc_mod);
    lola.addImport("wasm4", wasm4_mod);

    const opts = b.addOptions();
    opts.addOption(bool, "math", b.option(bool, "math", "enable the math module") orelse false);
    opts.addOption(bool, "stdlib", b.option(bool, "stdlib", "enable the stdlib module") orelse false);
    opts.addOption(bool, "runtime", b.option(bool, "runtime", "enable the runtime module") orelse false);
    opts.addOption(bool, "string", b.option(bool, "string", "enable the string module") orelse false);
    opts.addOption(bool, "byte_array", b.option(bool, "byte_array", "enable the bytearray module") orelse false);
    opts.addOption(bool, "array", b.option(bool, "array", "enable the array module") orelse false);
    const opts_mod = opts.createModule();
    exe_mod.addImport("build_opts", opts_mod);

    const exe = b.addExecutable(.{
        .name = "cart",
        .root_module = exe_mod,
    });

    exe.entry = .disabled;
    exe.root_module.export_symbol_names = &[_][]const u8{ "start", "update" };
    exe.import_memory = true;
    exe.initial_memory = 65536;
    exe.max_memory = 65536;
    exe.stack_size = 14752;

    const native = b.resolveTargetQuery(try std.Build.parseTargetQuery(.{}));
    const lola_native = b.dependency("lola", .{
        .optimize = optimize,
        .target = native,
    });
    const lola_exe_mod = lola_native.module("exe_mod");
    const lola_exe = b.addExecutable(.{
        .root_module = lola_exe_mod,
        .name = "lola",
    });
    const comp = b.addRunArtifact(lola_exe);
    comp.addArg("compile");
    comp.addDirectoryArg(b.path("prg/main.lola"));
    comp.addArg("-o");
    comp.addDirectoryArg(b.path("src/main.lola.lm"));
    exe.step.dependOn(&comp.step);
    b.installArtifact(exe);

    const run_exe = b.addSystemCommand(&.{ "w4", "run-native" });
    run_exe.addArtifactArg(exe);

    const step_run = b.step("run", "compile and run the cart");
    step_run.dependOn(&run_exe.step);
}
