#version 420 core
out vec4 fragment;
in vec2 v_uvCoords;
uniform sampler2D u_texture;
uniform vec4 u_color;

void main()
{
    fragment = vec4(u_color.rgb, texture(u_texture, v_uvCoords).a * u_color.a);
}