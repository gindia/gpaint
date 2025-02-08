package canvas

import w32 "core:sys/windows"
import gl  "vendor:opengl"
import     "core:fmt"
import     "core:os"

ENABLE_VSYNC :: true
GL_MAJOR     :: 4
GL_MINOR     :: 5

Canvas :: struct {
    hwnd:  w32.HWND,
    hdc:   w32.HDC,
    hglrc: w32.HGLRC,
    size:  [2]i32,
    keys:  [0xff]bool,
    mkeys: [2]bool, // mouse keys 0 left 1 right
    mpos:  [2]i32,
}

fatal :: proc (msg: string) {
    title := w32.utf8_to_utf16("FATAL!")
    msg := w32.utf8_to_utf16(msg)
    w32.MessageBoxW(nil, raw_data(msg), raw_data(title), w32.MB_ICONERROR)
    w32.ExitProcess(~u32(0))
}

load_wgl_functions :: proc () {
    class_name := w32.utf8_to_utf16("STATIC")
    dummy_hwnd := w32.CreateWindowExW(
		dwExStyle    = 0,
		lpClassName  = raw_data(class_name),
		lpWindowName = raw_data(class_name),
		dwStyle      = w32.WS_OVERLAPPED,
		X            = w32.CW_USEDEFAULT,
        Y            = w32.CW_USEDEFAULT,
        nWidth       = w32.CW_USEDEFAULT,
        nHeight      = w32.CW_USEDEFAULT,
		hWndParent   = nil,
		hMenu        = nil,
		hInstance    = nil,
		lpParam      = nil,
    )
    assert(dummy_hwnd != nil)

    hdc := w32.GetDC(dummy_hwnd)
    assert(hdc != nil)

	descriptor := w32.PIXELFORMATDESCRIPTOR {
		nSize      = size_of(w32.PIXELFORMATDESCRIPTOR),
		nVersion   = 1,
		dwFlags    = w32.PFD_DRAW_TO_WINDOW | w32.PFD_SUPPORT_OPENGL | w32.PFD_DOUBLEBUFFER,
		iPixelType = w32.PFD_TYPE_RGBA,
		cColorBits = 24,
	}

	format := w32.ChoosePixelFormat(hdc, &descriptor)
	if format == 0 {
		err := w32.GetLastError()
        fatal(fmt.tprint("Cannot choose OpenGL pixel format for dummy window! [", err, "]"))
	}

	if w32.DescribePixelFormat(hdc, format, size_of(descriptor), &descriptor) == 0 {
		fatal(fmt.tprint("Failed to describe OpenGL pixel format"))
	}

	if !w32.SetPixelFormat(hdc, format, &descriptor) {
		err := w32.GetLastError()
		fatal(fmt.tprint("Cannot set OpenGL pixel format for dummy window! [", err, "]"))
	}

	glrc := w32.wglCreateContext(hdc)
	if glrc == nil {
		fatal("Failed to create OpenGL context for dummy window")
	}

	if !w32.wglMakeCurrent(hdc, glrc) {
		err := w32.GetLastError()
		fatal(fmt.tprint("Failed to make current OpenGL context for dummy window [", err, "]"))
	}

    /////////////////////////////////////////
    /////////////////////////////////////////
    /////////////////////////////////////////

    // load the wgl functions

	w32.wglGetExtensionsStringARB   = auto_cast w32.wglGetProcAddress("wglGetExtensionsStringARB")
	w32.wglChoosePixelFormatARB     = auto_cast w32.wglGetProcAddress("wglChoosePixelFormatARB")
	w32.wglCreateContextAttribsARB  = auto_cast w32.wglGetProcAddress("wglCreateContextAttribsARB")
	w32.wglSwapIntervalEXT          = auto_cast w32.wglGetProcAddress("wglSwapIntervalEXT")

	if  (w32.wglChoosePixelFormatARB    == nil) ||
        (w32.wglGetExtensionsStringARB  == nil) ||
	    (w32.wglCreateContextAttribsARB == nil) ||
	    (w32.wglSwapIntervalEXT         == nil)
    {
		fatal("OpenGL does not support required WGL extensions for Creating a context!")
	}

    /////////////////////////////////////////
    /////////////////////////////////////////
    /////////////////////////////////////////

	// cleanup
	w32.wglMakeCurrent(nil, nil)
	w32.wglDeleteContext(glrc)
	w32.ReleaseDC(dummy_hwnd, hdc)
	w32.DestroyWindow(dummy_hwnd)
}

@(private)
w32_window_proc :: proc "stdcall" (wnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) -> w32.LRESULT {
	switch (msg) {
	case w32.WM_DESTROY:
		w32.PostQuitMessage(0)
		return 0
	}
	return w32.DefWindowProcW(wnd, msg, wparam, lparam)
}

@(private)
w32_get_window_size :: proc (hwnd: w32.HWND) -> [2]i32 {
	rect: w32.RECT
	w32.GetClientRect(hwnd, &rect)
	w := rect.right - rect.left
	h := rect.bottom - rect.top
    return { w, h }
}

init :: proc (name: string, #any_int width, height: int) -> Canvas {
    canvas: Canvas

    load_wgl_functions()

    wname := w32.utf8_to_utf16(name)

    hinstance := w32.GetModuleHandleW(nil)
    assert(hinstance != nil, "Failed to get module handle")

	// register window class to have custom WindowProc callback
	wc := w32.WNDCLASSEXW {
		cbSize        = size_of(w32.WNDCLASSEXW),
		lpfnWndProc   = w32_window_proc,
		hInstance     = transmute(w32.HANDLE) hinstance,
		hIcon         = w32.LoadIconA(nil, w32.IDI_APPLICATION),
		hCursor       = w32.LoadCursorA(nil, w32.IDC_ARROW),
		lpszClassName = raw_data(wname),
	}

	atom := w32.RegisterClassExW(&wc)
    assert(atom != 0, "Failed to register window class")

	// set window style/properties
	exstyle := w32.WS_EX_APPWINDOW
	style := w32.WS_OVERLAPPEDWINDOW

	// fix window size
	style &= ~w32.WS_THICKFRAME & ~w32.WS_MAXIMIZEBOX
	rect := w32.RECT{0, 0, cast(i32)width, cast(i32)height}
	w32.AdjustWindowRectEx(&rect, style, w32.FALSE, exstyle)
	width := rect.right - rect.left
	height := rect.bottom - rect.top

	// borderless
	style &= ~w32.WS_CAPTION
	style &= ~w32.WS_BORDER
	// style |= w32.WS_POPUPWINDOW // this gives a thin line around borders
	style |= w32.WS_POPUP

	// screen size
	screen_w := w32.GetSystemMetrics(w32.SM_CXSCREEN)
	screen_h := w32.GetSystemMetrics(w32.SM_CYSCREEN)

	x, y: i32
    x = (screen_w - width) / 2
    y = (screen_h - height) / 2

	// always on top
    // exstyle |= w32.WS_EX_TOPMOST

	// create window
	canvas.hwnd = w32.CreateWindowExW(
		dwExStyle    = exstyle,
		lpClassName  = raw_data(wname),
		lpWindowName = raw_data(wname),
		dwStyle      = style,
		X            = x,
        Y            = y,
        nWidth       = width,
        nHeight      = height,
		hWndParent   = nil,
		hMenu        = nil,
		hInstance    = wc.hInstance,
		lpParam      = nil,
	)

    assert(canvas.hwnd != nil, "Failed to create window")

	canvas.hdc = w32.GetDC(canvas.hwnd)
    assert(canvas.hdc != nil, fmt.tprintf("Failed to window device context [%v].", w32.GetLastError()))

	{ 	// set pixel format for OpenGL context
		attrib := []i32 {
			w32.WGL_DRAW_TO_WINDOW_ARB, 1, // GL_TRUE,
			w32.WGL_SUPPORT_OPENGL_ARB, 1, // GL_TRUE,
			w32.WGL_DOUBLE_BUFFER_ARB,  1, // GL_TRUE,
			w32.WGL_PIXEL_TYPE_ARB,     w32.WGL_TYPE_RGBA_ARB,
			w32.WGL_COLOR_BITS_ARB,     24,
			w32.WGL_DEPTH_BITS_ARB,     24,
			w32.WGL_STENCIL_BITS_ARB,   8,

			// uncomment for sRGB framebuffer, from WGL_ARB_framebuffer_sRGB extension
			// https://www.khronos.org/registry/OpenGL/extensions/ARB/ARB_framebuffer_sRGB.txt
			w32.WGL_FRAMEBUFFER_SRGB_CAPABLE_ARB, 1, // GL_TRUE,

			// uncomment for multisampled framebuffer, from WGL_ARB_multisample extension
			// https://www.khronos.org/registry/OpenGL/extensions/ARB/ARB_multisample.txt
			w32.WGL_SAMPLE_BUFFERS_ARB, 1,
			w32.WGL_SAMPLES_ARB,        4, // 4x MSAA

			0,
		}

		format: w32.INT
		formats: w32.UINT
		if (!w32.wglChoosePixelFormatARB(canvas.hdc, raw_data(attrib), nil, 1, &format, &formats) || formats == 0) {
			fatal("OpenGL does not support required pixel format!")
		}

		desc := w32.PIXELFORMATDESCRIPTOR {
			nSize = size_of(w32.PIXELFORMATDESCRIPTOR),
		}

		if w32.DescribePixelFormat(canvas.hdc, format, size_of(desc), &desc) == 0 {
			fatal("Failed to describe OpenGL pixel format")
		}

		if (!w32.SetPixelFormat(canvas.hdc, format, &desc)) {
			fatal("Cannot set OpenGL selected pixel format!")
		}
	} //

	{ 	// create modern OpenGL context

		attrib := []i32 {

            w32.WGL_CONTEXT_MAJOR_VERSION_ARB, GL_MAJOR,
            w32.WGL_CONTEXT_MINOR_VERSION_ARB, GL_MINOR,
            w32.WGL_CONTEXT_PROFILE_MASK_ARB,  w32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,

            // debug
            w32.WGL_CONTEXT_FLAGS_ARB, w32.WGL_CONTEXT_DEBUG_BIT_ARB,
            0,

        } when ODIN_DEBUG else []c.int {

            w32.WGL_CONTEXT_MAJOR_VERSION_ARB, GL_MAJOR,
            w32.WGL_CONTEXT_MINOR_VERSION_ARB, GL_MINOR,
            w32.WGL_CONTEXT_PROFILE_MASK_ARB,  w32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0,

        }

		canvas.hglrc = w32.wglCreateContextAttribsARB(canvas.hdc, nil, raw_data(attrib))

		if canvas.hglrc == nil {
			fatal("Cannot create modern OpenGL context! OpenGL version 4.5 not supported?")
		}

		if !w32.wglMakeCurrent(canvas.hdc, canvas.hglrc) {
			fatal("Failed to make current OpenGL context")
		}

		// load OpenGL functions
		gl.load_up_to(GL_MAJOR, GL_MINOR, w32.gl_set_proc_address)

		gl.Enable(gl.MULTISAMPLE)

		when ODIN_DEBUG {
			// enable debug callback
			// gl.DebugMessageCallback(gl_debug_callback, nil)
			gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
		}
	}

	// set to FALSE to disable vsync
	w32.wglSwapIntervalEXT(ENABLE_VSYNC ? 1 : 0)

	// show window
	w32.ShowWindow(canvas.hwnd, w32.SW_SHOWDEFAULT)

    canvas.size = w32_get_window_size(canvas.hwnd)

    ///////////////////////////////
    ///////////////////////////////

    // print init info

    gl_version := gl.GetString(gl.VERSION)
    gl_vendor := gl.GetString(gl.VENDOR)
    gl_render := gl.GetString(gl.RENDERER)

	fmt.printfln("*** Started %v %v", ODIN_OS, ODIN_ARCH_STRING)
    fmt.printfln("*** OpenGL %v.%v (%v)", GL_MAJOR, GL_MINOR, gl_version)
    fmt.printfln("*** GL vendor: %v", gl_vendor)
    fmt.printfln("*** GL renderer: %v", gl_render)
	fmt.printfln("*** Current Dir: '%v'", os.get_current_directory(context.temp_allocator))
	fmt.printfln("*** Canvas Size: %v", canvas.size)

    ///////////////////////////////
    ///////////////////////////////

	return canvas
}

frame_begin :: proc (canvas: ^Canvas) {

	// process all incoming Windows messages
	for msg: w32.MSG; w32.PeekMessageW(&msg, nil, 0, 0, w32.PM_REMOVE); {
		switch msg.message {

        /////////////////////////////

		case w32.WM_QUIT:
			w32.ExitProcess(0)

        /////////////////////////////

		// keyboard
		case w32.WM_KEYDOWN: canvas.keys[msg.wParam] = true
		case w32.WM_KEYUP:   canvas.keys[msg.wParam] = false

        /////////////////////////////

		// mouse
		case w32.WM_LBUTTONDOWN: canvas.mkeys[0] = true
		case w32.WM_LBUTTONUP:   canvas.mkeys[0] = false

		case w32.WM_RBUTTONDOWN: canvas.mkeys[0] = true
		case w32.WM_RBUTTONUP:   canvas.mkeys[0] = false

		case w32.WM_MOUSEMOVE:
            canvas.mpos = {
                cast(i32)(msg.lParam)       & 0xFFFF,
                cast(i32)(msg.lParam >> 16) & 0xFFFF,
            }

        /////////////////////////////

		} // switch

		w32.TranslateMessage(&msg)
		w32.DispatchMessageW(&msg)
	} // for


    // hardcode esc to shutdown in case of debug because reasons.
    when ODIN_DEBUG {
        if canvas.keys[w32.VK_ESCAPE] {
            w32.ExitProcess(0)
        }
    }
}

frame_end :: proc (canvas: ^Canvas) {

	wsize := w32_get_window_size(canvas.hwnd)
    canvas.size = wsize

	// window is minimized, cannot vsync - instead sleep a bit
	if (wsize.x == 0) || (wsize.y == 0) {
		if ENABLE_VSYNC {
			w32.Sleep(10)
			return
		}
	}

	if !w32.wglMakeCurrent(canvas.hdc, canvas.hglrc) do fatal("Failed to make current OpenGL context")
	if !w32.SwapBuffers(canvas.hdc) do fatal("Failed to swap OpenGL buffers!")
}
