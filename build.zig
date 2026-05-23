const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opus_dep = b.dependency("opus", .{ .target = target, .optimize = optimize });
    const ogg_dep = b.dependency("ogg", .{ .target = target, .optimize = optimize });

    const lib = b.addLibrary(.{
        .name = "opusfile",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib.root_module.linkLibrary(opus_dep.artifact("opus"));
    lib.root_module.linkLibrary(ogg_dep.artifact("ogg"));
    lib.root_module.addIncludePath(b.path("include"));
    lib.root_module.addCSourceFiles(.{ .files = &sources, .flags = &.{} });

    // iOS targets require the iOS SDK sysroot (libc headers are not bundled
    // with Zig). Pull the headers, frameworks, and stub libs from the bundled
    // `xcode_frameworks` package so the C sources can find <string.h> etc.
    if (target.result.os.tag == .ios) {
        if (b.lazyDependency("xcode_frameworks", .{
            .target = target,
            .optimize = optimize,
        })) |dep| {
            const subdir = if (target.result.abi == .simulator) "iphonesimulator" else "iphoneos";
            lib.root_module.addSystemFrameworkPath(dep.path(b.fmt("{s}/Frameworks", .{subdir})));
            lib.root_module.addSystemIncludePath(dep.path(b.fmt("{s}/include", .{subdir})));
            lib.root_module.addLibraryPath(dep.path(b.fmt("{s}/lib", .{subdir})));
        }
    }

    lib.installHeadersDirectory(b.path("include"), "", .{});
    lib.installLibraryHeaders(opus_dep.artifact("opus"));
    lib.installLibraryHeaders(ogg_dep.artifact("ogg"));
    b.installArtifact(lib);
}

const sources = [_][]const u8{
    "src/info.c",
    "src/internal.c",
    "src/opusfile.c",
    "src/stream.c",
};
