const std = @import("std");
const Allocator = std.mem.Allocator;
usingnamespace @import("util.zig");
usingnamespace @import("shader.zig");
usingnamespace @import("glm.zig");
usingnamespace @import("c_dependencies.zig");
usingnamespace @import("frame_context.zig");

pub const ImageRenderer = struct
{
    allocator: *Allocator,
    vao: c_uint,
    vbo: c_uint,
    shader: Shader,

    pub fn init(allocator: *Allocator) !ImageRenderer
    {
        var vao: c_uint = undefined;
        var vbo: c_uint = undefined;
        
        // setup text buffer
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, null);

        const vertices = [_]f32 
        { 
            0.0, 0.0, 0.0, 0.0, // bottom left
            1.0, 0.0, 1.0, 0.0, // bottom right
            0.0, 1.0, 0.0, 1.0, // top left 
            1.0, 0.0, 1.0, 0.0, // bottom right
            1.0, 1.0, 1.0, 1.0, // top right
            0.0, 1.0, 0.0, 1.0 // top left 
        };

        glBufferData(GL_ARRAY_BUFFER, @intCast(c_int, vertices.len * @sizeOf(f32)), &vertices[0], GL_STATIC_DRAW);
        glBindVertexArray(0);
        glCheck();
        
        var renderer = ImageRenderer {
            .allocator = allocator,
            .vao = vao,
            .vbo = vbo,
            .shader = try Shader.init(allocator,
                "data" ++ sep ++ "shaders" ++ sep ++ "image.vert.glsl", 
                "data" ++ sep ++ "shaders" ++ sep ++ "image.frag.glsl")
        };
        
        return renderer;
    }

    pub fn deinit(self: *ImageRenderer) void
    {
        if(self.vao > 0) glDeleteVertexArrays(1, &self.vao);
        if(self.vbo > 0) glDeleteBuffers(1, &self.vbo);
        self.shader.deinit();
    }

    pub fn tick(self: *ImageRenderer, context: FrameContext) void
    {
        if(context.resized)
        {
            var newValue = Vector2{.x=@intToFloat(f32, context.screenSize.x), .y=@intToFloat(f32, context.screenSize.y)};
            self.shader.use();
            self.shader.setVec2("u_screenSize", newValue);
        }

    }

    pub fn render(self: *ImageRenderer, textureId: c_uint, x: f32, y: f32, w: f32, h: f32, angle: f32) !void
    {
        var pos = Vector2 {.x = x, .y = y };
        var imageSize = Vector2 {.x = w, .y = h };
        //float rotMat[16] =
        // {
        //      cos(ang_rad), sin(ang_rad),  0.0f, 0.0f,
        //     -sin(ang_rad), cos(ang_rad ), 0.0f, 0.0f,
        //      0.0f,         0.0f,          1.0f, 0.0f,
        //      0.0f,         0.0f,          0.0f, 1.0f
        // };
        var angRad = deg2rad(angle);
        var rotationMatrix = Mat4.identity();
        rotationMatrix.vals[0][0] = cos(angRad);
        rotationMatrix.vals[1][0] = sin(angRad);
        rotationMatrix.vals[0][1] = -sin(angRad);
        rotationMatrix.vals[1][1] = cos(angRad);

        _ = rotationMatrix;

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        self.shader.use();
        self.shader.setVec2("u_scale", imageSize);
        self.shader.setVec2("u_position", pos);
        self.shader.setMat4("u_rotation", rotationMatrix);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textureId);

        glBindVertexArray(self.vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glDisable(GL_BLEND);
    }
};