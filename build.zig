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

    b.installArtifact(exe);

    const run_exe = b.addSystemCommand(&.{ "w4", "run-native" });
    run_exe.addArtifactArg(exe);

    const step_run = b.step("run", "compile and run the cart");
    step_run.dependOn(&run_exe.step);
}
