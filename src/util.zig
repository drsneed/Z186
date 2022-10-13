
const std = @import("std");
const builtin = @import("builtin");
usingnamespace @import("c_dependencies.zig");
usingnamespace @import("glm.zig");
usingnamespace @import("tga_loader.zig");
const Allocator = std.mem.Allocator;
const StringList = std.ArrayList([]const u8);
pub const sep = std.fs.path.sep_str;


//  {} (primitives) print the default primitive representation (if it exists)
// {c} (int): print as an ascii character
// {b} (int): print as binary
// {x} (int): print as lowercase hex
// {X} (int): print as uppercase hex
// {o} (int): print as octal
// {e} (float): print in exponent form
// {d} (int/float): print in base10/decimal form
// {d:.2} control float precision
// {s} ([]u8/*u8): print as null-terminated string
// {*} (any): print as a pointer (hex) (NOTE: does & make more sense here?)
// {?} (any): print full debug representation (e.g. traverse structs etc to primitive fields)
// {#} (any): print raw bytes of the value (hex) (NOTE: do we need this? how often is it used?)


pub fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    if (std.builtin.mode == std.builtin.Mode.Debug) {
        std.debug.warn(fmt, args);
    }
}

pub fn pathExists(path: []const u8) bool {
    if (std.fs.cwd().access(path, std.fs.File.OpenFlags{ .read = true, .write = false }))
        |_| return true else |_| return false;
}

pub fn glCheck() void
{
    switch(glGetError()) {
        GL_INVALID_ENUM => {std.debug.panic("gl error: Invalid enum.\n", .{});},
        GL_INVALID_VALUE => {std.debug.panic("gl error: Invalid value.\n", .{});},
        GL_INVALID_OPERATION => {std.debug.panic("gl error: Invalid operation.\n", .{});},
        GL_INVALID_FRAMEBUFFER_OPERATION => {std.debug.panic("gl error: Invalid framebuffer operation.\n", .{});},
        GL_OUT_OF_MEMORY => {std.debug.panic("gl error: Out of memory.\n", .{});},
        GL_STACK_UNDERFLOW => {std.debug.panic("gl error: Stack underflow.\n", .{});},
        GL_STACK_OVERFLOW => {std.debug.panic("gl error: Stack overflow.\n", .{});},
        else => {}
    }
}

pub fn loadTexture(allocator: *Allocator, filePath: []const u8) !c_uint
{
    if(!pathExists(filePath)) {
        debugPrint("file '{s}' does not exist.\n", .{filePath});
        return error.ImageNotFound;
    }

    var image = TgaImage.init(allocator);
    defer image.deinit();
    try image.loadFromFile(filePath);
    var textureId:c_uint = undefined;
    std.debug.assert(image.width != 0);
    glGenTextures(1, &textureId);
    glBindTexture(GL_TEXTURE_2D, textureId);
    defer glBindTexture(GL_TEXTURE_2D, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, image.width, image.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, @ptrCast(*const c_void, &image.image[0]));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    return textureId;
}


pub fn fromHex(color: u32) Vec4
{
    return vec4( 
        @intToFloat(f32, color >> 24 & 0xFF) / 255.0,
        @intToFloat(f32, color >> 16 & 0xFF) / 255.0,
        @intToFloat(f32, color >> 8  & 0xFF) / 255.0,
        @intToFloat(f32, color & 0xFF) / 255.0);
}