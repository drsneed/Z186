const std = @import("std");
const Allocator = std.mem.Allocator;
usingnamespace @import("bitmap_font.zig");
usingnamespace @import("bitmap_char.zig");
usingnamespace @import("bitmap_string.zig");
usingnamespace @import("../util.zig");
usingnamespace @import("../shader.zig");
usingnamespace @import("../glm.zig");
usingnamespace @import("../c_dependencies.zig");
usingnamespace @import("../frame_context.zig");

pub const BitmapFontRenderer = struct
{
    const Vertex2d = struct { x: f32, y: f32, u: f32, v: f32 };
    const Corner = enum {TopLeft, TopRight, BottomRight, BottomLeft};
    const SpaceWidth:f32 = 8.0;

    allocator: *Allocator,
    vao: c_uint,
    vbo: c_uint,
    depth: f32,
    shader: Shader,
    lastText: [256]u8,
    vertexCount: c_int,
    pub fn init(allocator: *Allocator) !BitmapFontRenderer
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
        glBindVertexArray(0);
        glCheck();
        var renderer = BitmapFontRenderer {
            .allocator = allocator,
            .vao = vao,
            .vbo = vbo,
            .depth = -1.0,
            .lastText = undefined,
            .vertexCount = 0,
            .shader = try Shader.init(allocator,
                "data" ++ sep ++ "shaders" ++ sep ++ "bitmap_font.vert.glsl", 
                "data" ++ sep ++ "shaders" ++ sep ++ "bitmap_font.frag.glsl")
        };
        
        return renderer;
    }

    pub fn deinit(self: *BitmapFontRenderer) void
    {
        if(self.vao > 0) glDeleteVertexArrays(1, &self.vao);
        if(self.vbo > 0) glDeleteBuffers(1, &self.vbo);
        self.shader.deinit();
    }

    fn generateVertices(self: *BitmapFontRenderer, font: *BitmapFont, text: []const u8) !std.ArrayList(Vertex2d)
    {
        if(text.len > self.lastText.len) return error.TextTooLarge;
        var vertices = std.ArrayList(Vertex2d).init(self.allocator);
        var cursor = Vector2.init(0.0, 0.0);
        var i:usize = 0;       

        while(i < text.len) : (i = i + 1) {
            switch(text[i]) {
                ' ' => {
                    cursor.x = cursor.x + SpaceWidth;
                },
                '\n' => {
                    cursor.y = cursor.y + @intToFloat(f32, font.common.lineHeight);
                    cursor.x = 0.0;
                },
                else => { if(font.getChar(text[i])) |char| {
                    // position coords for left, right, top, bottom
                    var xl = cursor.x + @intToFloat(f32, char.xoffset);
                    var xr = cursor.x + @intToFloat(f32, char.xoffset + char.width);
                    var yt = cursor.y + @intToFloat(f32, char.yoffset);
                    var yb = cursor.y + @intToFloat(f32, char.yoffset + char.height);
                    // uv coords for left, right, top, bottom
                    var ul = @intToFloat(f32, char.x) / @intToFloat(f32, font.common.scaleW);
                    var ur = @intToFloat(f32, char.x + char.width) / @intToFloat(f32, font.common.scaleW);
                    var vt = (@intToFloat(f32, char.y) / @intToFloat(f32, font.common.scaleH));
                    var vb = (@intToFloat(f32, char.y + char.height) / @intToFloat(f32, font.common.scaleH));
                    // define corner vertices
                    var topLeft = Vertex2d { .x = xl, .y = yt, .u = ul, .v = vt };
                    var topRight = Vertex2d { .x = xr, .y = yt, .u = ur, .v = vt };
                    var bottomRight = Vertex2d { .x = xr, .y = yb, .u = ur, .v = vb };
                    var bottomLeft = Vertex2d { .x = xl, .y = yb, .u = ul, .v = vb };
                    // Append quad to vertex array (two tris).
                    try vertices.append(bottomLeft);
                    try vertices.append(bottomRight);
                    try vertices.append(topLeft);
                    try vertices.append(bottomRight);
                    try vertices.append(topRight);
                    try vertices.append(topLeft);
                    // advance cursor, utilizing kerning if exists
                    var kerningAmount:i32 = 0;
                    if(i < text.len - 1) {
                        if(font.getChar(text[i+1])) |nextChar| {
                            if(font.getKerning(char.id, nextChar.id)) |kerning| {
                                kerningAmount = kerning.amount;
                            }
                        }
                    }
                    cursor.x = cursor.x + @intToFloat(f32, char.xadvance + kerningAmount);
                }}
            }
        }
        return vertices;
    }

    pub fn tick(self: *BitmapFontRenderer, context: FrameContext) void
    {
        self.depth = -1.0;
        if(context.resized)
        {
            var newValue = Vector2{.x=@intToFloat(f32, context.screenSize.x), .y=@intToFloat(f32, context.screenSize.y)};
            debugPrint("setting u_screenSize = {d},{d}\n", .{newValue.x, newValue.y});
            self.shader.use();
            self.shader.setVec2("u_screenSize", newValue);
        }

    }

    pub fn render(self: *BitmapFontRenderer, font: *BitmapFont, pos: Vector2, color: u32, textureId: c_uint, text: []const u8) !void
    {
        if(!std.mem.eql(u8, self.lastText[0..], text[0..])) {
            _ = try std.fmt.bufPrint(self.lastText[0..], "{s}", .{text});
            var vertices = try self.generateVertices(font, text);
            if(vertices.items.len == 0) return;
            self.vertexCount = @intCast(c_int, vertices.items.len);
            glBindBuffer(GL_ARRAY_BUFFER, self.vbo);
            glBufferData(GL_ARRAY_BUFFER, @intCast(c_int, vertices.items.len * @sizeOf(Vertex2d)), &vertices.items[0], GL_DYNAMIC_DRAW);
        }

            // we assume only one texture exists
        var textScale = Vector2 {.x=0.666, .y=0.666};
        
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        self.shader.use();
        self.shader.setFloat("u_depth", self.depth);
        self.shader.setVec2("u_scale", textScale);
        self.shader.setVec2("u_position", pos);
        self.shader.setVec4("u_color", fromHex(color));
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textureId);
        glBindVertexArray(self.vao);
        glDrawArrays(GL_TRIANGLES, 0, self.vertexCount);
        glDisable(GL_BLEND);
        self.depth = self.depth + 0.01;
    }
};