package main

import     "core:fmt"
import     "core:time"
import glm "core:math/linalg/glsl"
import gl  "vendor:opengl"
import     "canvas"

main :: proc () {
    CNV := canvas.init("el-window", 712, 712*9/16)

    // set time
    frame_tick := time.tick_now()
    elapsed_time: f32

    TTF :: #load("cousine-regular.ttf")
    font := canvas.load_font(TTF, ' ', '~', 15, CNV.size)

    for {
        // frame
        canvas.frame_begin(&CNV); defer canvas.frame_end(&CNV)

        // time
        delta        := f32(time.tick_lap_time(&frame_tick)) / f32(time.Second)
        elapsed_time += delta

        // drawing
        gl.ClearColor(glm.sin(elapsed_time), 0.1, 0.1, 0.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        canvas.draw_text(font, "foo", 10, 10)

        free_all(context.temp_allocator)
    }
}
