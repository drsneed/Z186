#version 420 core
out vec4 fragment;
in vec2 v_uvCoords;
uniform sampler2D u_texture;
void main()
{
    fragment = texture(u_texture, v_uvCoords);
}