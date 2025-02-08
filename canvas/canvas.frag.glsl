#version 450 core

in vec2 frag_uv;

out vec4 out_color;

uniform sampler2D texture0;

void main() {
    vec4 texel = texture(texture0, frag_uv);
    out_color = texel;
    // out_color = vec4(1.0, 0.0, 0.0, 1.0);
}
