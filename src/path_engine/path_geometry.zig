const std = @import("std");
usingnamespace @import("../c_dependencies.zig");
usingnamespace @import("../util.zig");
usingnamespace @import("../glm.zig");

pub const PathGeometry = struct
{
    vao: c_uint = 0,
    vbo: c_uint = 0,

    pub fn init() PathGeometry
    {
        var geometry = PathGeometry {};
        glGenVertexArrays(1, &geometry.vao);
        glBindVertexArray(geometry.vao);
        defer glBindVertexArray(0);
        glGenBuffers(1, &geometry.vbo);
        glBindBuffer(GL_ARRAY_BUFFER, geometry.vbo);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
        glCheck();
        return geometry;
    }

    pub fn deinit(self: *PathGeometry) void
    {
        if(self.vao > 0) glDeleteVertexArrays(1, &self.vao);
        if(self.vbo > 0) glDeleteBuffers(1, &self.vbo);
    }

    pub fn fill(self: *PathGeometry, path: std.ArrayList(Vector2)) void 
    {
        glBindVertexArray(self.vao);
        glBindBuffer(GL_ARRAY_BUFFER, self.vbo);
        glBufferData(GL_ARRAY_BUFFER, @intCast(c_long, path.items.len * @sizeOf(Vector2)), &path.items[0], GL_DYNAMIC_DRAW);
    }
};