#version 430 core

in vec2 frag_uv;

out vec4 out_color;

uniform sampler2D texture0;
uniform vec4      u_color;

void main() {
    float a = texture(texture0, frag_uv).r;
    out_color = vec4(u_color.xyz, a);
}
