const std = @import("std");
const path = std.fs.path;
const builtin = @import("builtin");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void
{
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("Z186", "src/main.zig");

    exe.linkLibC();

    switch(builtin.os.tag)
    {
        .windows => {
            exe.addLibPath("deps/glfw3/lib/windows");
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("shell32");
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
        },
        .linux => {
            exe.addLibPath("deps/glfw3/lib/linux");
            exe.linkSystemLibrary("x11");
            exe.linkSystemLibrary("glfw3");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("gl");
            exe.linkSystemLibrary("z");
        },
        else => {},
    }

    exe.linkSystemLibrary("glfw3");
    exe.addIncludeDir("deps/glfw3");

    // compile glad
    exe.addIncludeDir("deps/glad");
    exe.addCSourceFile("deps/glad/glad.c", &[_][]const u8{"-std=c99"});
    
    // compile stb_image
    exe.addIncludeDir("deps/stb_image");
    exe.addCSourceFile("deps/stb_image/stb_image.c", &[_][]const u8{"-std=c99"});
    

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
