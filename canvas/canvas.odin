package canvas

import glm   "core:math/linalg/glsl"
import gl    "vendor:opengl"
import stbtt "vendor:stb/truetype"
import       "core:image"
import       "core:fmt"

vec2 :: glm.vec2
vec3 :: glm.vec3
vec4 :: glm.vec4
mat4 :: glm.mat4

Image :: image.Image
Glyph :: stbtt.packedchar

Font :: struct {
    texture:           u32, // atlas
    t_width, t_height: int,
    glyphs:            []Glyph,
	font_size:         f32, // this is the font size in the conjured utils.
	first_unicode:     rune,
    last_unicode:      rune,

    program:            u32,
    u_color, u_proj:   i32, // uniform locs

    vao:               u32,
    vbo:               u32,
    ebo:               u32,

    canvas_size:       [2]i32,
}

load_font :: proc (
    ttf:            []byte,
    first_unicode:  rune,
    last_unicode:   rune,
    font_size:      f32,
    canvas_size:    [2]i32,
    allocator    := context.allocator
) -> Font {

    /////////////////////////////

    // 1 - generage image pixels and glyphs

	WIDTH  :: 1024
	HEIGHT :: 1024

	pixels := make([]u8, WIDTH * HEIGHT, context.temp_allocator)

	assert(int(last_unicode) > int(first_unicode), "the smalles in range is larger than the largest ... ?")
	glyphs := make([]stbtt.packedchar, int(last_unicode) - int(first_unicode), allocator)

	spc: stbtt.pack_context
	if stbtt.PackBegin(&spc, raw_data(pixels), WIDTH, HEIGHT, WIDTH, 1, nil) == 0 {
		panic("failed to load a font")
	}
	defer stbtt.PackEnd(&spc)

	stbtt.PackSetOversampling(&spc, 4, 4)
	ranges := []stbtt.pack_range {
		{
			font_size = font_size,
			first_unicode_codepoint_in_range = i32(first_unicode),
			num_chars = i32(last_unicode - first_unicode),
			chardata_for_range = raw_data(glyphs),
		},
	}
	stbtt.PackFontRanges(&spc, raw_data(ttf), 0, raw_data(ranges), cast(i32)len(ranges))

    /////////////////////////////

    // 2 - load texture from image

    texture: u32
    {
        gl.GenTextures(1, &texture)
        gl.BindTexture(gl.TEXTURE_2D, texture)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, WIDTH, HEIGHT, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(pixels))
        gl.GenerateMipmap(gl.TEXTURE_2D)

        assert(texture != 0, "failed to create a gl texture handle")
    }

    /////////////////////////////

    // 3 - load shader
    program: u32
    {
        VS_SOURCE :: cast(string) #load("./font.vert.glsl")
        FS_SOURCE :: cast(string) #load("./font.frag.glsl")
        ok: bool
        program, ok = gl.load_shaders_source(VS_SOURCE, FS_SOURCE)
        assert(ok, fmt.tprint(gl.get_last_error_message()))
    }

    u_color := gl.GetUniformLocation(program, "u_color")
    u_proj := gl.GetUniformLocation(program, "u_proj")


    /////////////////////////////

    // 4 - init gl vertex objects

    vao, vbo, ebo: u32
    {
        gl.GenVertexArrays(1, &vao)
        gl.BindVertexArray(vao); defer gl.BindVertexArray(0)

        gl.GenBuffers(1, &vbo)
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
		gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 0, 0) // vec4

		gl.GenBuffers(1, &ebo)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    }

    ///

    return {
        texture       = texture,
        t_width       = WIDTH,
        t_height      = HEIGHT,
        glyphs        = glyphs,
        font_size     = font_size,
        first_unicode = first_unicode,
        last_unicode  = last_unicode,
        program       = program,
        u_color       = u_color,
        u_proj        = u_proj,
        vao           = vao,
        vbo           = vbo,
        ebo           = ebo,
        canvas_size   = canvas_size,
    }
}

get_glyph_info :: proc (font: Font, r: rune) -> Glyph {
	if r >= font.first_unicode && r <= font.last_unicode {
		index := cast(int)r - cast(int)font.first_unicode
		return font.glyphs[index]
	}

	// use '_' as fallback letter
	index := cast(int)'_' - cast(int)font.first_unicode
	return font.glyphs[index]
}

glyph_to_quad :: proc (font: Font, glyph: Glyph, offset: vec2) -> (quad: [4][4]f32, x_advance: f32) {

	x_advance = glyph.xadvance

	iw := 1.0 / f32(font.t_width)
	ih := 1.0 / f32(font.t_height)

	yoffset := font.font_size * 0.75 // well it fits and i don't care if its a hack!

	// top left
	quad[0] = [4]f32 {
		offset.x + glyph.xoff,
		offset.y + glyph.yoff + yoffset,
		f32(glyph.x0) * iw,
		f32(glyph.y0) * ih,
	}

	// top right
	quad[1] = [4]f32 {
		offset.x + glyph.xoff2,
		offset.y + glyph.yoff + yoffset,
		f32(glyph.x1) * iw,
		f32(glyph.y0) * ih,
	}

	// bot left
	quad[2] = [4]f32 {
		offset.x + glyph.xoff,
		offset.y + glyph.yoff2 + yoffset,
		f32(glyph.x0) * iw,
		f32(glyph.y1) * ih,
	}

	// bot right
	quad[3] = [4]f32 {
		offset.x + glyph.xoff2,
		offset.y + glyph.yoff2 + yoffset,
		f32(glyph.x1) * iw,
		f32(glyph.y1) * ih,
	}

	return
}

messure_text :: proc (font: Font, text: string) -> vec2 {
    out: vec2
	for char in text {
        glyph := get_glyph_info(font, char)
        out.x += f32(glyph.xadvance)
	}
    out.y = font.font_size // set H to font size.
    return out
}

draw_text :: proc (font: Font, text: string, x, y: f32, color: [4]u8 = 255) {

	color := [4]f32 {
		f32(color.r) / 255.0,
		f32(color.g) / 255.0,
		f32(color.b) / 255.0,
		f32(color.a) / 255.0,
	}

	vertices := make([][4]f32, len(text) * 4, context.temp_allocator)
	indices  := make([dynamic]u16, 0, len(text) * 6, context.temp_allocator)

    cursor := vec2{x, y}

	for char, i in text {

        glyph := get_glyph_info(font, char)
		quad, x_advance := glyph_to_quad(font, glyph, cursor)

        cursor.x += x_advance

		idx := u16(i * 4)

		// top left
		vertices[idx] = quad[0]

		// top right
		vertices[idx + 1] = quad[1]

		// bot left
		vertices[idx + 2] = quad[2]

		// bot right
		vertices[idx + 3] = quad[3]

		append(&indices,
			// triangle 1
			idx + 0, idx + 1, idx + 2,
			// triangle 2
			idx + 1, idx + 2, idx + 3,
		)
	}

    gl.Disable(gl.CULL_FACE)
    gl.Disable(gl.DEPTH_TEST)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Enable(gl.BLEND)

    gl.UseProgram(font.program); defer gl.UseProgram(0)
    gl.BindVertexArray(font.vao); defer gl.BindVertexArray(0)

    gl.EnableVertexAttribArray(0)

    if font.u_color != -1 {
        gl.Uniform4fv(font.u_color, 1, cast([^]f32) &color[0])
    }

    if font.u_proj != -1 {
        proj := glm.mat4Ortho3d(0, cast(f32) font.canvas_size.x, cast(f32) font.canvas_size.y, 0, -0.1, 0.1)
        gl.UniformMatrix4fv(font.u_proj, 1, false, cast([^]f32) &proj[0])
    }

    //
    gl.BindBuffer(gl.ARRAY_BUFFER, font.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(vec4), raw_data(vertices), gl.STREAM_DRAW)

    //
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, font.ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u16), raw_data(indices), gl.STREAM_DRAW)

    // texture
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, font.texture)

    //
    gl.DrawElements(gl.TRIANGLES, cast(i32)len(indices), gl.UNSIGNED_SHORT, nil)
}
