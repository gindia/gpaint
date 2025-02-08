package main

import     "core:fmt"
import     "core:time"
import     "core:math"
import glm "core:math/linalg/glsl"
import gl  "vendor:opengl"
import     "canvas"
import     "window"

main :: proc () {
    window.init("el-window", canvas.CANVAS_WIDTH, canvas.CANVAS_HEIGHT)

    // set time
    frame_tick := time.tick_now()
    elapsed_time: f32

    // canvas
    canvas.load_canvas()

    // font
    TTF :: #load("cousine-regular.ttf")
    font := canvas.load_font(TTF, ' ', '~', 15, window.WINDOW.size)

    for {
        // clear arena
        free_all(context.temp_allocator)

        // frame
        window.frame_begin(); defer window.frame_end()

        // time
        delta        := f32(time.tick_lap_time(&frame_tick)) / f32(time.Second)
        elapsed_time += delta

        // win.set_position(&window, 10, 100 + 100 * math.sin(elapsed_time))

        // drawing
        gl.ClearColor(0.1, 0.1, 0.1, 0.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        if window.WINDOW.mkeys[0] {
            canvas.blit_buffer(window.WINDOW.mpos, 10)
        }

        if window.WINDOW.keys[int('Q')] {
            canvas.clear_canvas()
        }

        canvas.draw_cavnas()
        canvas.draw_text(font, fmt.tprint("foo", window.WINDOW.mpos), 10, 10)
    }
}
