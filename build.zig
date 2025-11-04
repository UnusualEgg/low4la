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

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
    });
    exe_mod.addImport("lola", lola);

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
