const std = @import("std");
const builtin = @import("builtin");
usingnamespace @import("util.zig");
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const cwd = std.fs.cwd;
const OpenFlags = std.fs.File.OpenFlags;

const glm = @import("glm.zig");
const Mat4 = glm.Mat4;
const Vec3 = glm.Vec3;
const Vec4 = glm.Vec4;

usingnamespace @import("c_dependencies.zig");

pub const Shader = struct 
{
    id: c_uint,

    pub fn init(allocator: *Allocator, vertexPath: []const u8, fragmentPath: []const u8) !Shader {
        // 1. retrieve the vertex/fragment source code from filePath
        const vShaderFile = try cwd().openFile(vertexPath, OpenFlags{ .read = true, .write = false });
        defer vShaderFile.close();

        const fShaderFile = try cwd().openFile(fragmentPath, OpenFlags{ .read = true, .write = false });
        defer fShaderFile.close();

        var vertexCode = try allocator.alloc(u8, (try vShaderFile.getEndPos()) + 1);
        defer allocator.free(vertexCode);

        var fragmentCode = try allocator.alloc(u8, (try fShaderFile.getEndPos()) + 1);
        defer allocator.free(fragmentCode);

        const vLen = try vShaderFile.read(vertexCode);
        const fLen = try fShaderFile.read(fragmentCode);
        vertexCode[vLen] = 0;
        fragmentCode[fLen] = 0;
        // 2. compile shaders
        // vertex shader
        const vertex = glCreateShader(GL_VERTEX_SHADER);
        const vertexSrcPtr: ?[*]const u8 = vertexCode.ptr;
        glShaderSource(vertex, 1, &vertexSrcPtr, null);
        glCompileShader(vertex);
        errorCheck(vertex, "Vertex");
        // fragment Shader
        const fragment = glCreateShader(GL_FRAGMENT_SHADER);
        const fragmentSrcPtr: ?[*]const u8 = fragmentCode.ptr;
        glShaderSource(fragment, 1, &fragmentSrcPtr, null);
        glCompileShader(fragment);
        errorCheck(fragment, "Fragment");
        const id = glCreateProgram();
        glAttachShader(id, vertex);
        glAttachShader(id, fragment);
        glLinkProgram(id);
        errorCheck(id, "Program");
        // delete the shaders as they're linked into our program now and no longer necessary
        glDeleteShader(vertex);
        glDeleteShader(fragment);
        glCheck();
        return Shader{ .id = id };
    }

    pub fn deinit(self: Shader) void
    {
        if(self.id != 0)
        {
            glDeleteProgram(self.id);
        }
    }

    pub fn use(self: Shader) void {
        glUseProgram(self.id);
    }

    pub fn setBool(self: Shader, name: [:0]const u8, val: bool) void {
        _ = self;
        _ = name;
        _ = val;
        // glUniform1i(glGetUniformLocation(ID, name.c_str()), (int)value);
    }

    pub fn setInt(self: Shader, name: [:0]const u8, val: c_int) void {
        glUniform1i(glGetUniformLocation(self.id, name), val);
    }

    pub fn setFloat(self: Shader, name: [:0]const u8, val: f32) void {
        glUniform1f(glGetUniformLocation(self.id, name), val);
    }

    pub fn setMat4(self: Shader, name: [:0]const u8, val: Mat4) void {
        glUniformMatrix4fv(glGetUniformLocation(self.id, name), 1, GL_FALSE, &val.vals[0][0..][0]);
    }
    pub fn setVec2(self: Shader, name: [:0]const u8, val: glm.Vector2) void {
        glUniform2f(glGetUniformLocation(self.id, name), val.x, val.y);
    }
    pub fn setVec3(self: Shader, name: [:0]const u8, val: Vec3) void {
        glUniform3f(glGetUniformLocation(self.id, name), val.vals[0], val.vals[1], val.vals[2]);
    }

    pub fn setVec4(self: Shader, name: [:0]const u8, val: Vec4) void {
        glUniform4f(glGetUniformLocation(self.id, name), val.vals[0], val.vals[1], val.vals[2], val.vals[3]);
    }
    fn errorCheck(handle: c_uint, errType: []const u8) void {
        var result: c_int = undefined;
        var infoLog: [1024]u8 = undefined;
        std.crypto.utils.secureZero(u8, infoLog[0..]);
        if (!std.mem.eql(u8, errType, "Program")) {
            glGetShaderiv(handle, GL_COMPILE_STATUS, &result);
            if (result == 0) {
                glCheck();
                glGetShaderInfoLog(handle, 1024, null, &infoLog);
                panic("{d} shader compilation failed:\n{s}\n", .{ errType, infoLog });
            }
        } else {
            glUseProgram(handle);
            glGetProgramiv(handle, GL_LINK_STATUS, &result);
            if (result == 0) {
                glGetProgramInfoLog(handle, 1024, null, &infoLog);
                panic("{d} program link failed:\n{s}\n", .{handle, infoLog});
            }
        }
    }
};
