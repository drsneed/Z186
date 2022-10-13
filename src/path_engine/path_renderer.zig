/// std imports
const std = @import("std");
// const Allocator = std.mem.Allocator;


usingnamespace @import("../c_dependencies.zig");
usingnamespace @import("../util.zig");
usingnamespace @import("../shader.zig");
usingnamespace @import("../glm.zig");
usingnamespace @import("../camera.zig");

usingnamespace @import("path_geometry.zig");

pub const PathRenderer = struct
{
    dynamicBuffer: PathGeometry,
    dynamicBufferLen: c_int,
    flatShader: Shader,
    pub fn init(allocator: *std.mem.Allocator) !PathRenderer
    {
        return PathRenderer {
            .dynamicBuffer = PathGeometry.init(),
            .dynamicBufferLen = 0,
            .flatShader = try Shader.init(allocator,
                "data" ++ sep ++ "shaders" ++ sep ++ "flat.vert.glsl", 
                "data" ++ sep ++ "shaders" ++ sep ++ "flat.frag.glsl")
        };
    }

    pub fn fillDynamicBuffer(self: *PathRenderer, path: std.ArrayList(Vector2)) void {
        self.dynamicBuffer.fill(path);
        self.dynamicBufferLen = @intCast(c_int, path.items.len);
    }

    pub fn drawDynamicBuffer(self: *PathRenderer, camera: *Camera, color: u32) void {
        glDisable(GL_CULL_FACE);
        glEnable(GL_BLEND);
        var mvp = camera.viewProjectionMatrix;
        self.flatShader.use();
        self.flatShader.setMat4("u_mvp", mvp);
        self.flatShader.setVec4("u_color", fromHex(color));
        glBindVertexArray(self.dynamicBuffer.vao);
        glDrawArrays(GL_TRIANGLES, 0, self.dynamicBufferLen);
    }

    pub fn deinit(self: *PathRenderer) void
    {
       self.dynamicBuffer.deinit();
       self.flatShader.deinit();
    }
};