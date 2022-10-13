#version 420 core
layout(location = 0) in vec4 vertex;
out vec2 v_uvCoords;
uniform vec2  u_screenSize;
uniform vec2  u_scale;
uniform vec2  u_position;
uniform float u_depth;

void main()
{
    vec2 position = vertex.xy;
    v_uvCoords = vertex.zw;
    position *= u_scale;
    position += u_position;
    position.y = u_screenSize.y - position.y;
    vec2 half_size = u_screenSize / 2;
    position = (position-half_size)/half_size;
    gl_Position = vec4(position, u_depth, 1);

}