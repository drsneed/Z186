const std = @import("std");
usingnamespace @import("../frame_context.zig");
usingnamespace @import("../util.zig");
usingnamespace @import("../c_dependencies.zig");
pub const PathBuilder = struct
{

    enabled: bool = false,
    width: f32 = 0.0,

    pub fn init(allocator: *std.mem.Allocator) PathBuilder {
        _ = allocator;
        return PathBuilder {};
    }

    pub fn build(self: *PathBuilder, width: f32) void {
        self.enabled = true;
        self.width = width;
    }

    pub fn tick(self: *PathBuilder, context: *FrameContext) void {
        if(!self.enabled)
            return;

        if(context.wasButtonClicked(GLFW_MOUSE_BUTTON_LEFT))
        {
            debugPrint("Left button click used by path builder\n", .{});
        }
    }
};