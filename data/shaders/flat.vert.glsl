#version 420 core
in vec2 position;
uniform mat4 u_mvp;

void main()
{
    gl_Position = u_mvp * vec4(position.x, 0, position.y, 1);
}
