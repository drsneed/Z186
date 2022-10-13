
const std = @import("std");
const Allocator = std.mem.Allocator;
usingnamespace @import("c_dependencies.zig");
usingnamespace @import("glm.zig");
usingnamespace @import("frame_context.zig");
usingnamespace @import("tga_loader.zig");

fn glfwError(err: c_int, description: [*c]const u8) callconv(.C) void
{
    std.debug.panic("Error {d}: {s}\n", .{err, description});
}


fn windowResizedCallback(win: ?*GLFWwindow, width: c_int, height: c_int) callconv(.C) void
{
    _ = win;
    _ = width;
    _ = height;
    // glViewport(0, 0, width, height);
    // windowWidth = @intToFloat(f32, width);
    // windowHeight = @intToFloat(f32, height);
}

fn mouseMotionCallback(win: ?*GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void 
{
    _ = win;
    _ = xpos;
    _ = ypos;
    // var xrel = xpos - lastMouseX;
    // var yrel = ypos - lastMouseY;
    // lastMouseX = xpos;
    // lastMouseY = ypos;
}

fn mouseButtonCallback(win: ?*GLFWwindow, button: i32, action: i32, mods: i32) callconv(.C) void 
{
    _ = win;
    _ = button;
    _ = action;
    _ = mods;
}

var lastMouseWheel: i32 = 0;

pub fn getLastMouseWheel() i32 {return lastMouseWheel;}

fn mouseScrollCallback(win: ?*GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void 
{
    _ = win;
    _ = xoffset;
    lastMouseWheel = @floatToInt(i32, yoffset);
}

pub const Window = struct
{
    handle: *GLFWwindow = undefined,
    //@intToFloat(f32, HEIGHT);

    pub fn init(title: [] const u8, width: i32, height: i32) Window 
    {
        _ = glfwSetErrorCallback(glfwError);
        if (glfwInit() == GL_FALSE) std.debug.panic("GLFW init failure\n", .{});
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);

        var handle = glfwCreateWindow(width, height, @ptrCast([*c]const u8, title), null, null) orelse {
            std.debug.panic("unable to create window\n", .{});
        };

        glfwMakeContextCurrent(handle);
        glfwSwapInterval(1);
        _ = glfwSetFramebufferSizeCallback(handle, windowResizedCallback);
        _ = glfwSetCursorPosCallback(handle, mouseMotionCallback);
        _ = glfwSetScrollCallback(handle, mouseScrollCallback);
        _ = glfwSetMouseButtonCallback(handle, mouseButtonCallback);

        if (gladLoadGLLoader(@ptrCast(GLADloadproc, glfwGetProcAddress)) == 0) {
            std.debug.panic("Failed to initialise GLAD\n", .{});
        }

        var window = Window {.handle = handle};
        return window;
    }

    pub fn tick(self: *Window, context: *FrameContext) void {
        _ = self;
        context.mouseWheel = lastMouseWheel;
        lastMouseWheel = 0;
    }

    pub fn getMousePos(self: Window) Vector2 {
        var x:f64 = 0.0;
        var y:f64 = 0.0;
        glfwGetCursorPos(self.handle, &x, &y);
        return Vector2 {.x = @floatCast(f32, x), .y= @floatCast(f32, y)};
    }

    pub fn getSize(self: Window) Vector2i
    {
        var result = Vector2i {};
        glfwGetWindowSize(self.handle, &result.x, &result.y);
        return result;
    }

    pub fn setIcon(self: Window, allocator: *Allocator, filePath: []const u8) !void {
        var image = TgaImage.init(allocator);
        defer image.deinit();
        try image.loadFromFile(filePath);
        if(image.width == 0) return error.ImageNotFound;
        var glfwImage = GLFWimage {
            .width = @intCast(c_int, image.width),
            .height = @intCast(c_int, image.height),
            .pixels = @ptrCast([*c] u8, &image.image[0])
        };
        glfwSetWindowIcon(self.handle, 1, &glfwImage);
    }

    pub fn deinit(self: *const Window) void
    {
        _ = self;
        glfwTerminate();
    }
};