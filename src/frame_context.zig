usingnamespace @import("glm.zig");
usingnamespace @import("window.zig");
usingnamespace @import("c_dependencies.zig");
usingnamespace @import("util.zig");

pub const FrameContext = struct
{
    deltaTime: f32 = 0.0,
    screenSize: Vector2i = Vector2i {.x = 0, .y = 0},
    resized:bool = false,
    mouseWheel:i32 = 0,
    mouseMotion:bool = false,
    mousePos:Vector2 = Vector2 {.x = 0.0, .y=0.0},
    mouseRel:Vector2 = Vector2 {.x = 0.0, .y=0.0},
    mouseWorldPos:Vector2 = Vector2 {.x = 0.0, .y = 0.0},
    clicked: [3]bool = [3]bool {false,false,false},
    pressed: [3]bool = [3]bool {false,false,false},
    fps: i32 = 0,
    fpsAux: i32 = 0,
    timer: f32 = 0.0,
    lastTime: f64 = 0.0,
    window: *Window = undefined,

    pub fn init(myWindow: *Window) FrameContext {
        return FrameContext {
            .window = myWindow
        };
    }

    pub fn isButtonDown(self: FrameContext, button: c_int) bool {
        return self.pressed[@intCast(usize,button)];
    }

    pub fn wasButtonClicked(self: *FrameContext, button: c_int) bool {
        var index = @intCast(usize,button);
        var clicked = self.clicked[index];
        self.clicked[index] = false;
        return clicked;
    }

    fn updateButton(self: *FrameContext, button: c_int) void
    {
        var i = @intCast(usize,button);
        var wasDownLastFrame = self.pressed[i];
        self.pressed[i] = glfwGetMouseButton(self.window.handle, button) == GLFW_PRESS;
        self.clicked[i] = wasDownLastFrame and !self.pressed[i];
    }

    fn updateMouseWorldPos(self: *FrameContext) void
    {
        _ = self;
    }


    fn updateTime(self: *FrameContext) void 
    {
        var thisTime:f64 = glfwGetTime();
        self.deltaTime = @floatCast(f32, thisTime - self.lastTime);
        self.lastTime = thisTime;
        self.fpsAux = self.fpsAux + 1;
        self.timer = self.timer + self.deltaTime;
        if (self.timer >= 1.0)
        {
            self.fps = self.fpsAux;
            self.fpsAux = 0;
            self.timer = 0.0;
        }
    }

    pub fn update(self: *FrameContext) void
    {
        self.updateTime();
        var screenSize = self.window.getSize();
        self.resized = (screenSize.x != self.screenSize.x or screenSize.y != self.screenSize.y);
        self.screenSize = screenSize;
        var button:c_int = GLFW_MOUSE_BUTTON_LEFT;
        while(button < GLFW_MOUSE_BUTTON_MIDDLE) : (button = button + 1) {
            self.updateButton(button);
        }
        var mousePos = self.window.getMousePos();
        self.mouseRel.x = mousePos.x - self.mousePos.x;
        self.mouseRel.y = mousePos.y - self.mousePos.y;
        self.mouseMotion = mousePos.x != self.mousePos.x or mousePos.y != self.mousePos.y;
        self.mousePos = mousePos;

        self.updateMouseWorldPos();


        // _frameContext.IsKeyPressed = std::bind(&GlWindow::IsKeyPressed, this, std::placeholders::_1);
        // _frameContext.mouseWheel = _lastMouseWheel;
        // //_frameContext.mouseInUiRect = nk_window_is_any_hovered(&_uiContext);

    }
};