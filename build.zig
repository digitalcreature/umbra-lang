const std = @import("std");

const Pkg = std.build.Pkg;

const pkgs = struct {

    const util = Pkg {
        .name = "util",
        .path = "src/util/_.zig",
    };
    
    const compile = Pkg {
        .name = "compile",
        .path = "src/compile/_.zig",
        .dependencies = &.{ util },
    };

    const cli = Pkg {
        .name = "cli",
        .path = "src/cli/_.zig",
        .dependencies = &.{ util, compile },
    };

};

const pkg_list: []const Pkg = blk: {
    const decls = std.meta.declarations(pkgs);
    var result: [decls.len]Pkg = undefined;
    inline for (decls) |decl, i| {
        result[i] = @field(pkgs, decl.name);
    }
    break :blk &result;
};


pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("umbra", "src/main.zig");
    exe.setTarget(target);
    for (pkg_list) |pkg| {
        exe.addPackage(pkg);
    }
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);


    const test_step = b.step("test", "Run library tests");

    for (pkg_list) |pkg| {
        var pkg_test_step = b.addTest(pkg.path);
        pkg_test_step.setBuildMode(mode);
        var log_name_step = b.addLog("\x1b[7mTesting Package {s} ({s})\x1b[0m\n", .{pkg.name, pkg.path});
        pkg_test_step.step.dependOn(&log_name_step.step);
        if (pkg.dependencies) |dependencies| {
            for (dependencies) |dep| {
                pkg_test_step.addPackage(dep);
            }
        }
        test_step.dependOn(&pkg_test_step.step);
    }

}

fn createPackageTestStep(b: *std.build.Builder, pkg: std.build.Pkg) *std.build.Step {
}