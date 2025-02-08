package canvas

import     "core:mem"
import     "core:fmt"
import gl  "vendor:opengl"
import glm "core:math/linalg/glsl"
import     "../window"

CANVAS_HEIGHT :: 1024
CANVAS_WIDTH  :: 1024 * 5 / 4

// 0xRR_GG_BB_AA
HexColor :: distinct u32be

Canvas :: struct {
    buffer:   [CANVAS_WIDTH * CANVAS_HEIGHT] HexColor,
    texture:  u32,
    program:  u32,
    vao:      u32,
    vbo:      u32,
    ebo:      u32,
}

CANVAS: Canvas

load_canvas :: proc () {

    /////////////////////////////

    // 1 - load texture

    texture: u32
    {
        gl.GenTextures(1, &texture)
        gl.BindTexture(gl.TEXTURE_2D, texture)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, CANVAS_WIDTH, CANVAS_HEIGHT, 0,
            gl.RGBA, gl.UNSIGNED_BYTE, raw_data(CANVAS.buffer[:]))
        // gl.GenerateMipmap(gl.TEXTURE_2D)

        assert(texture != 0, "failed to create a gl texture handle")
    }

    /////////////////////////////

    // 2 - load shader
    program: u32
    {
        VS_SOURCE :: cast(string) #load("./canvas.vert.glsl")
        FS_SOURCE :: cast(string) #load("./canvas.frag.glsl")
        ok: bool
        program, ok = gl.load_shaders_source(VS_SOURCE, FS_SOURCE)
        assert(ok, fmt.tprint(gl.get_last_error_message()))
    }

    u_proj  := gl.GetUniformLocation(program, "u_proj")

    /////////////////////////////

    // 3 - init gl vertex objects

    vao, vbo, ebo: u32
    {
        quad: [4][4]f32

        //                 x    y  s  t
        // top left
        quad[0] = [4]f32 { -1, -1, 0, 1 }

        // top right
        quad[1] = [4]f32 {  1, -1, 1, 1 }

        // bot left
        quad[2] = [4]f32 { -1,  1, 0, 0 }

        // bot right
        quad[3] = [4]f32 {  1,  1, 1, 0 }

        indices := [6]u16 {
			// triangle 1
			0, 1, 2,
			// triangle 2
			1, 2, 3,
        }

        gl.GenVertexArrays(1, &vao)
        gl.BindVertexArray(vao); defer gl.BindVertexArray(0)

        gl.GenBuffers(1, &vbo)
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
		gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 0, 0) // vec4

        gl.BufferData(gl.ARRAY_BUFFER, len(quad) * size_of(vec4), raw_data(quad[:]), gl.STATIC_DRAW)

        //
		gl.GenBuffers(1, &ebo)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u16), raw_data(indices[:]), gl.STATIC_DRAW)
    }

    ///

    CANVAS.texture = texture
    CANVAS.program = program
    CANVAS.vao     = vao
    CANVAS.vbo     = vbo
    CANVAS.ebo     = ebo
}

blit_buffer :: proc (center, size: [2]i32, color: HexColor = 0x00_FF_00_FF) {

    /////////////////////////////

    // 1 - blit buffer

    buffer := CANVAS.buffer[:][:]

    top_left := center - (size / 2)
    // fmt.println("blit ->", top_left)

    for j in top_left.y ..< top_left.y + size.y {
        for i in top_left.x ..< top_left.x + size.x {
            buffer[(j * CANVAS_WIDTH) + i] = color
        }
    }

    /////////////////////////////

    // 2 - update texture

    gl.BindTexture(gl.TEXTURE_2D, CANVAS.texture)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, CANVAS_WIDTH, CANVAS_HEIGHT, 0,
        gl.RGBA, gl.UNSIGNED_BYTE, raw_data(CANVAS.buffer[:]))

}

draw_cavnas :: proc () {

    gl.Disable(gl.CULL_FACE)
    gl.Disable(gl.DEPTH_TEST)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Enable(gl.BLEND)

    gl.UseProgram(CANVAS.program); defer gl.UseProgram(0)
    gl.BindVertexArray(CANVAS.vao); defer gl.BindVertexArray(0)

    gl.EnableVertexAttribArray(0)

    // texture
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, CANVAS.texture)

    //
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, nil)
}

clear_canvas :: proc () {
    mem.zero_slice(CANVAS.buffer[:])
    gl.BindTexture(gl.TEXTURE_2D, CANVAS.texture)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, CANVAS_WIDTH, CANVAS_HEIGHT, 0,
        gl.RGBA, gl.UNSIGNED_BYTE, raw_data(CANVAS.buffer[:]))
}
