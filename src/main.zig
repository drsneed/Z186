const std = @import("std");
usingnamespace @import("c_dependencies.zig");
usingnamespace @import("glm.zig");
usingnamespace @import("window.zig");
usingnamespace @import("util.zig");
usingnamespace @import("camera.zig");
usingnamespace @import("frame_context.zig");
usingnamespace @import("image_renderer.zig");
usingnamespace @import("bitmap_font/bitmap_font.zig");
usingnamespace @import("path_engine/polyline2d.zig");
usingnamespace @import("path_engine/path_renderer.zig");
usingnamespace @import("path_engine/path_builder.zig");

// ------------------- PROGRAM DEFAULTS -------------------------------

const allocator = std.heap.c_allocator;
// ------------------------------------------------------------------

var frameContext:FrameContext = undefined;


// ------------------------------------------------------------------

var window:Window = undefined;

pub fn main() !void 
{

    window = Window.init("A Thing", 1120, 620);
    defer window.deinit();
    // set the glfw custom pointer to point to our window object, to be used in callbacks
    _ = glfwSetWindowUserPointer(window.handle, &window);

    try window.setIcon(allocator, "data" ++ sep ++ "images" ++ sep ++ "icon.tga");

    //const bgColor = fromHex(0x7DA17CFF);
    const bgColor = fromHex(0x222222FF);
    glClearColor(bgColor.vals[0], bgColor.vals[1], bgColor.vals[2], bgColor.vals[3]);
    glCheck();


    frameContext = FrameContext.init(&window);

    var bitmapFont = try BitmapFont.init(allocator, "data" ++ sep ++ "fonts" ++ sep ++ "Tahoma" ++ sep ++ "tahoma.fnt");
    defer bitmapFont.deinit();

    var imageRenderer = try ImageRenderer.init(allocator);
    defer imageRenderer.deinit();

    var textureId = try loadTexture(allocator, "data" ++ sep ++ "images" ++ sep ++ "test1.tga");
    defer glDeleteTextures(1, &textureId);

    var angle: f32 = 0.0;

    var textPosition:Vector2 = Vector2 {.x = 510.0, .y = 300.0};

    var camera = Camera.init();

    var pathRenderer = try PathRenderer.init(allocator);
    defer pathRenderer.deinit();

    var points = std.ArrayList(Vector2).init(allocator);
    defer points.deinit();
    try points.append(Vector2 {.x = 10.0, .y = 10.0});
    try points.append(Vector2 {.x = 40.0, .y = 10.0});
    try points.append(Vector2 {.x = 40.0, .y = 40.0});
    var polyline = try Polyline2d.create(allocator, points, 
        1.0, 
        Polyline2d.JointStyle.Round,
        Polyline2d.EndCapStyle.Butt,
        true);
    debugPrint("polyline len: {}\n", .{polyline.items.len});
    defer polyline.deinit();
    pathRenderer.fillDynamicBuffer(polyline);


    var pathBuilder = PathBuilder {};
    pathBuilder.build(5.0);

    while (glfwWindowShouldClose(window.handle) == 0) 
    {
        frameContext.update();
        window.tick(&frameContext);
        camera.tick(frameContext);
        bitmapFont.renderer.tick(frameContext);
        imageRenderer.tick(frameContext);
        pathBuilder.tick(&frameContext);

        //angle += frameContext.deltaTime * 25.0;
        if(angle > 360.0)
            angle = 0.0;


        if(frameContext.resized) {
            glViewport(0, 0, frameContext.screenSize.x, frameContext.screenSize.y);
        }
        
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        

        pathRenderer.drawDynamicBuffer(&camera, 0xFFFFFFFF);


        try imageRenderer.render(textureId, 200.0, 200.0, 256.0, 256.0, angle);

        bitmapFont.render(textPosition, 0x0807A0FF, "We are doing a thing.", .{}) catch |err| {
            debugPrint("Error rendering text: {s}\n", .{err});
            std.os.exit(0);
        };
        


        glfwSwapBuffers(window.handle);
        glfwPollEvents();
        glCheck();
    }
}
