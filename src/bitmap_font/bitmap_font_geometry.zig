const std = @import("std");
const Allocator = std.mem.Allocator;
usingnamespace @import("bitmap_font.zig");
usingnamespace @import("bitmap_char.zig");
usingnamespace @import("bitmap_string.zig");
usingnamespace @import("../util.zig");
usingnamespace @import("../c_dependencies.zig");

pub const BitmapFontGeometry = struct
{
    vao: c_uint = 0,
    vbo: c_uint = 0,
    ebo: c_uint = 0,

    pub fn init() BitmapFontGeometry
    {
        var geometry = BitmapFontGeometry {};
        glGenVertexArrays(1, &geometry.vao);
        glBindVertexArray(geometry.vao);
        defer glBindVertexArray(0);
        glGenBuffers(1, &geometry.vbo);
        glBindBuffer(GL_ARRAY_BUFFER, geometry.vbo);
        // top left, top right, bottom left, top right, bottom right, bottom left
        const vertices = [_]f32 {0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 1.0, -1.0, 0.0, 1.0, 0.0, 0.0};
        const indices = [_]u32 { 0, 1, 2, 0, 2, 3 };

        glBufferData(GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices[0], GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);
        glGenBuffers(1, &geometry.ebo);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geometry.ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices[0], GL_STATIC_DRAW);
        glCheck();
        return geometry;
    }

    pub fn deinit(self: *BitmapFontGeometry) void
    {
        if(self.vao > 0) glDeleteVertexArrays(1, &self.vao);
        if(self.ebo > 0) glDeleteBuffers(1, &self.ebo);
        if(self.vbo > 0) glDeleteBuffers(1, &self.vbo);
        
    }

    pub fn generate(self: *BitmapFontGeometry, font: *BitmapFontDescriptor, text: []const u8) void
    {

    }
};