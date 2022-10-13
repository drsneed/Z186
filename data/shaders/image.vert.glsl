#version 420 core
layout(location = 0) in vec4 vertex;
out vec2 v_uvCoords;
uniform vec2  u_screenSize;
uniform vec2  u_scale;
uniform vec2  u_position;
uniform mat4 u_rotation;
void main()
{
    vec2 position =  vertex.xy;
    position *= u_scale;
    
    vec2 halfPosition = position * vec2(0.5, 0.5);
    vec2 tempPos = position + halfPosition;
    tempPos = (u_rotation * vec4(tempPos, 0, 1)).xy;
    tempPos = tempPos - halfPosition;
    position = tempPos;
    v_uvCoords = vertex.zw;

    
    position += u_position;
    position.y = u_screenSize.y - position.y;
    vec2 half_size = u_screenSize / 2;
    position = (position-half_size)/half_size;
    gl_Position = vec4(position, 0, 1);
}