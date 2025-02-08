#version 450 core

layout (location = 0) in vec4 a_xyst;

out vec2 frag_uv;

void main() {
    gl_Position = vec4(a_xyst.xy, 0.0, 1.0);
    frag_uv = a_xyst.zw;
}
