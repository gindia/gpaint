#version 430 core

layout (location = 0) in vec4 a_xyst;

out vec2 frag_uv;

uniform mat4 u_proj;

void main() {
    gl_Position = u_proj * vec4(a_xyst.xy, 0.0, 1.0);
    frag_uv = a_xyst.zw;
}
