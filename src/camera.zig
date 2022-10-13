const std = @import("std");
usingnamespace @import("glm.zig");
usingnamespace @import("util.zig");
usingnamespace @import("c_dependencies.zig");
usingnamespace @import("frame_context.zig");

pub const Camera = struct 
{
    const CameraState = enum
    {
        Idle,
        Strafing,
        Rotating,
        StrafingEaseOut,
        RotatingEaseOut
    };

    const CameraMinY:f32 = 20.0;
    const CameraMaxY:f32 = 60.0;
    const DefaultVelocity:f32 = 40.0;

    /// Minimum distance camera must move in one strafe session to trigger an ease-out effect
    const MinimumStrafeDistance:f32 = 20.0;
    /// Minimum time (in seconds) that camera must be strafing in order to trigger an ease-out effect
    const MinimumStrafeDuration:f32 = 0.5;
    // ---------------------------------------------------------------------------

    velocity: Vector2 = Vector2 {.x=0.0, .y=0.0},
    strafeStartPoint: Vector2 = Vector2 {.x=0.0, .y=0.0},
    strafeDuration: f32 = 0.0,
    easeDuration: f32 = 0.0,
    idleStrafeTimer: f32 = 0.0,
    currentState: CameraState = CameraState.Idle,
    position: Vec3 = vec3(0.0, CameraMaxY, 0.0),
    right: Vec3 = vec3(1.0,0.0,0.0),
    up: Vec3 = vec3(0.0,1.0,0.0),
    dirty: bool = true,
    rot: f32 = 0.0,
    fov: f32 = deg2rad(90.0),
    viewMatrix: Mat4 = Mat4.identity(),
    projectionMatrix: Mat4 = Mat4.identity(),
    viewportMatrix: Mat4 = Mat4.identity(),
    viewProjectionMatrix: Mat4 = Mat4.identity(),
    invViewProjMatrix: Mat4 = Mat4.identity(),
    lastMousePos: Vector2 = Vector2 {.x=0.0, .y=0.0},

    pub fn init() Camera {
        return Camera {};
    }

    fn onScreenResize(self: *Camera, width: i32, height: i32) void
    {
        if (width == 0 and height == 0) return;
        const fwidth = @intToFloat(f32, width);
        const fheight = @intToFloat(f32, height);
        var w2 = fwidth / 2.0;
        var h2 = fheight / 2.0;
        self.projectionMatrix = perspective(self.fov, fwidth/fheight, 1.0, 100000.0);
        self.viewportMatrix = Mat4{
        .vals = [4][4]f32{
            .{ w2, 0.0, 0.0, 0.0 },
            .{ 0.0, h2, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ w2, h2, 0.0, 1.0 }
        }};
        // self.viewportMatrix = mat4
        // (
        //     w2, 0.f, 0.f, w2,
        //     0.f, h2, 0.f, h2,
        //     0.f, 0.f, 1.f, 0.f,
        //     0.f, 0.f, 0.f, 1.f
        // );
    }

    fn handleEvents(self: *Camera, context: FrameContext) void
    {
        if (context.isButtonDown(GLFW_MOUSE_BUTTON_LEFT) and self.currentState != CameraState.Strafing) {
            self.currentState = CameraState.Strafing;
            self.strafeStartPoint = context.mousePos;
            self.strafeDuration = 0.0;
        } else if (!context.isButtonDown(GLFW_MOUSE_BUTTON_LEFT) and self.currentState == CameraState.Strafing) {
            var from = self.strafeStartPoint;
            var to = context.mousePos;
            var diff = to.sub(from);
            var dist = distance(from, to);
            if (dist >= MinimumStrafeDistance and 
                self.strafeDuration <= MinimumStrafeDuration and
                self.idleStrafeTimer <= 0.25) {
                    self.currentState = CameraState.StrafingEaseOut;
                    self.velocity = Vector2 {
                        .x= (diff.x / self.strafeDuration) * 0.005,
                        .y= (diff.y / self.strafeDuration) * 0.005 };
                    self.easeDuration = 1.0;
            } else {
                self.currentState = CameraState.Idle;
            }
        }
        if (context.mouseMotion) {
            self.idleStrafeTimer = 0.0;
            //Global::CursorGroundPoint = ScreenPointToGroundPoint(ctx.mousePos, ctx.windowSize);
            if (self.currentState == CameraState.Strafing) {
                // move faster at higher altitudes
                var d = lerp(unlerp(self.position.vals[1], CameraMinY, CameraMaxY), 0.01, 3.0);
                self.position.vals[0] = self.position.vals[0] - (context.mouseRel.x) * d;
                self.position.vals[2] = self.position.vals[2] - (context.mouseRel.y) * d;
                self.dirty = true;
            }
        } else {
            self.idleStrafeTimer = self.idleStrafeTimer + context.deltaTime;
        }
        if(context.resized) {
            self.onScreenResize(context.screenSize.x, context.screenSize.y);
        }
        if(context.mouseWheel != 0) {
            self.zoom(context.mouseWheel);
        }
    }

    fn zoom(self: *Camera, dir: i32) void {
        if(dir == -1) {
            var y_t = lerp(unlerp(self.position.vals[1], 0.0, 1000.0), 0.0, 1.0);
            var zoom_amount = 10.0 + (y_t * 60.0);
            self.position.vals[1] = std.math.max(std.math.min(self.position.vals[1] + zoom_amount, 1000.0), 0.0);
        } else {
            var y_t = lerp(unlerp(self.position.vals[1], 1000.0, 0.0), 1.0, 0.0);
            var zoom_amount = 10.0 + (y_t * 60.0);
            self.position.vals[1] = std.math.max(std.math.min(self.position.vals[1] - zoom_amount, 1000.0), 0.0);
        }
        self.dirty = true;
        
    }

    fn strafeEaseOutTick(self: *Camera, context: FrameContext) void
    {
        var acceleration = self.velocity.mulScalar(context.deltaTime * 6.0);
        self.easeDuration = self.easeDuration * context.deltaTime;
        self.velocity = self.velocity.sub(acceleration);
        self.position = vec3(self.position.vals[0] + self.velocity.x, self.position.vals[1], self.position.vals[2] + self.velocity.y);
        if (self.easeDuration <= 0.0)
            self.currentState = CameraState.Idle;
    }

    fn idleTick(self: *Camera, context: FrameContext) void
    {
        var forward = self.right.cross(self.up);
        var velocity = DefaultVelocity * context.deltaTime;

        if(glfwGetKey(context.glfwHandle, 'R') == GLFW_PRESS)
        {
            self.rot = self.rot + 5.0;
            self.dirty = true;
        }
        if (glfwGetKey(context.glfwHandle, 'W') == GLFW_PRESS)
        {
            var moveAmount = forward.mulScalar(velocity);
            self.position = self.position.add(moveAmount);
            self.dirty = true;
        }
        if (glfwGetKey(context.glfwHandle, 'S') == GLFW_PRESS)
        {
            var moveAmount = forward.mulScalar(-velocity);
            self.position = self.position.add(moveAmount);
            self.dirty = true;
        }
        if (glfwGetKey(context.glfwHandle, 'A') == GLFW_PRESS)
        {
            var moveAmount = self.right.mulScalar(velocity);
            self.position = self.position.add(moveAmount);
            self.dirty = true;
        }
        if (glfwGetKey(context.glfwHandle, 'D') == GLFW_PRESS)
        {
            var moveAmount = self.right.mulScalar(-velocity);
            self.position = self.position.add(moveAmount);
            self.dirty = true;
        }
        if (glfwGetKey(context.glfwHandle, 'Q') == GLFW_PRESS)
        {
            var moveAmount = self.up.mulScalar(velocity * 16.0);
            self.position = self.position.add(moveAmount);
            self.dirty = true;
        }
        if (glfwGetKey(context.glfwHandle, 'E') == GLFW_PRESS)
        {
            var moveAmount = self.up.mulScalar(-velocity * 16.0);
            self.position = self.position.add(moveAmount);
            self.dirty = true;
        }
    }


    fn updateInternal(self: *Camera, context: FrameContext) void
    {
        _ = context;
        var yaw = rotation(self.rot, self.up);
        self.right = transform(yaw, vec3(1, 0, 0));
        var u = self.right.cross(self.up.negate());
        self.viewMatrix = Mat4.identity();
        self.viewMatrix.vals[0][0] = self.right.vals[0];
        self.viewMatrix.vals[1][0] = self.right.vals[1];
        self.viewMatrix.vals[2][0] = self.right.vals[2];
        self.viewMatrix.vals[0][1] = u.vals[0];
        self.viewMatrix.vals[1][1] = u.vals[1];
        self.viewMatrix.vals[2][1] = u.vals[2];
        self.viewMatrix.vals[0][2] = self.up.vals[0];
        self.viewMatrix.vals[1][2] = self.up.vals[1];
        self.viewMatrix.vals[2][2] = self.up.vals[2];
        self.viewMatrix.vals[3][0] = -self.right.dot(self.position);
        self.viewMatrix.vals[3][1] = -u.dot(self.position);
        self.viewMatrix.vals[3][2] = self.up.negate().dot(self.position);
        self.viewProjectionMatrix = self.projectionMatrix.matmul(self.viewMatrix);
        //self.invViewProjMatrix = glm::inverse(_viewProjMatrix);

        // Global::CursorGroundPoint = ScreenPointToGroundPoint2(gWindow->GetMousePos());
        self.dirty = false;
    }

    pub fn tick(self: *Camera, context: FrameContext) void
    {
        self.handleEvents(context);

        switch(self.currentState)
        {
            CameraState.Idle => {self.idleTick(context);},
            CameraState.Strafing => {self.strafeDuration = self.strafeDuration + context.deltaTime;},
            CameraState.StrafingEaseOut => {self.strafeEaseOutTick(context);},
            else => {}
        }

        if(self.dirty) self.updateInternal(context);
        
    }


// if(ctx.windowResized)
// {
// auto size = ctx.windowSize;
// onScreenResize(size.x, size.y);
// }


// if (_dirty) _UpdateInternal(ctx.mousePos, ctx.windowSize);	
// }

};

